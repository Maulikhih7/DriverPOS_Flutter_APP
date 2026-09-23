import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../repositories/customer_repository.dart';
import '../repositories/pos_repository.dart';
import '../services/payment_service.dart';

// Cart pages default to this walk-in account rather than starting unassigned.
const String _defaultGuestEmail = 'guest@golfpro.com';

// ── Department & Label filters ────────────────────────────────────────────────

final selectedDepartmentProvider = StateProvider<String?>((ref) => null);
final selectedLabelProvider = StateProvider<String?>((ref) => null);
final productSearchProvider = StateProvider<String>((ref) => '');

// ── Departments ───────────────────────────────────────────────────────────────

final departmentsProvider =
    FutureProvider<List<DepartmentModel>>((ref) async {
  return ref
      .read(posRepositoryProvider)
      .getDepartments(salesCart: true);
});

// ── Labels for selected department ───────────────────────────────────────────

final labelsProvider =
    FutureProvider.autoDispose<List<LabelModel>>((ref) async {
  final deptName = ref.watch(selectedDepartmentProvider);
  if (deptName == null) return [];
  return ref.read(posRepositoryProvider).getLabels(department: deptName);
});

// ── Products (always via /label/products) ─────────────────────────────────────

final productsProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final deptName = ref.watch(selectedDepartmentProvider);
  final labelId = ref.watch(selectedLabelProvider);
  final search = ref.watch(productSearchProvider);

  if (deptName == null && search.isEmpty) return [];

  return ref.read(posRepositoryProvider).getProducts(
        departmentId: deptName,
        labelId: labelId,
        name: search.isNotEmpty ? search : null,
        limit: 50,
      );
});

// ── Server-side current sales cart ────────────────────────────────────────────

final viewSalesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.read(posRepositoryProvider).getViewSales(cartState: 'Sale');
});

// ── Hold carts list ───────────────────────────────────────────────────────────

final holdCartsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(posRepositoryProvider).getHoldCarts();
});

// ── Cart config ───────────────────────────────────────────────────────────────

final cartConfigProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(posRepositoryProvider).getCartConfig();
});

// TPN mapped to the logged-in workstation's terminal — not a value fixed on
// the device. The login/cart-config responses only carry a trimmed terminal
// summary (no tpn), so this looks up the full terminal doc by the id on the
// current user. Falls back to the locally saved TPN only when that lookup
// has nothing (e.g. offline, or terminal unmapped).
final mappedTpnProvider = FutureProvider.autoDispose<String?>((ref) async {
  final terminalId = ref.watch(authProvider).user?.terminal?.id;
  if (terminalId != null && terminalId.isNotEmpty) {
    try {
      final terminal =
          await ref.read(posRepositoryProvider).getTerminalDetails(terminalId);
      final tpn = terminal?['tpn'] as String?;
      if (tpn != null && tpn.isNotEmpty) {
        await PaymentService.saveTPN(tpn);
        return tpn;
      }
    } catch (_) {
      // network/lookup failure — fall through to local cache below
    }
  }
  return PaymentService.getSavedTPN();
});

// ── Cart ──────────────────────────────────────────────────────────────────────

class CartState {
  final List<CartItem> items;
  final CustomerModel? customer;
  final bool isCheckingOut;
  final String? error;
  final String? holdId;

  const CartState({
    this.items = const [],
    this.customer,
    this.isCheckingOut = false,
    this.error,
    this.holdId,
  });

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.totalDiscountedPrice);

  double get totalTax =>
      items.fold(0, (sum, item) => sum + (item.totalTaxAmount * item.totalQuantity));

  double get addonSubtotal =>
      items.fold(0, (sum, item) => sum + item.addOns.priceWithoutTax);

  double get addonTax =>
      items.fold(0, (sum, item) => sum + item.addOns.totalTax);

  double get total => subtotal + totalTax + addonSubtotal + addonTax;

  CartState copyWith({
    List<CartItem>? items,
    CustomerModel? customer,
    bool? isCheckingOut,
    String? error,
    String? holdId,
    bool clearError = false,
    bool clearCustomer = false,
    bool clearHoldId = false,
  }) {
    return CartState(
      items: items ?? this.items,
      customer: clearCustomer ? null : (customer ?? this.customer),
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      error: clearError ? null : (error ?? this.error),
      holdId: clearHoldId ? null : (holdId ?? this.holdId),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final PosRepository _repo;
  final CustomerRepository _customerRepo;
  final Ref _ref;

  CartNotifier(this._repo, this._customerRepo, this._ref)
      : super(const CartState()) {
    _loadDefaultCustomer();
  }

  Future<void> _loadDefaultCustomer() async {
    if (state.customer != null) return;
    try {
      final results =
          await _customerRepo.getCustomers(search: _defaultGuestEmail, limit: 5);
      final guest = results.firstWhere(
        (c) => (c.email ?? '').toLowerCase() == _defaultGuestEmail,
      );
      if (state.customer == null) {
        state = state.copyWith(customer: guest);
      }
    } catch (_) {
      // No guest account configured for this business, or offline —
      // leave unselected so the cashier picks a customer manually.
    }
  }

  void addProduct(ProductModel product) {
    final existingIndex =
        state.items.indexWhere((i) => i.item.id == product.id);
    if (existingIndex >= 0) {
      final updated = state.items.toList();
      final existing = updated[existingIndex];
      final newQty = existing.totalQuantity + 1;
      updated[existingIndex] = existing.copyWith(
        totalQuantity: newQty,
        totalDiscountedPrice: existing.discountPrice * newQty,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
          items: [...state.items, CartItem.fromProduct(product, 1)]);
    }
  }

  void removeProduct(int index) {
    final updated = state.items.toList()..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      removeProduct(index);
      return;
    }
    final updated = state.items.toList();
    final item = updated[index];
    updated[index] = item.copyWith(
      totalQuantity: quantity,
      totalDiscountedPrice: item.discountPrice * quantity,
    );
    state = state.copyWith(items: updated);
  }

  void setCustomer(CustomerModel customer) {
    state = state.copyWith(customer: customer);
  }

  void clearCart() {
    state = const CartState();
    _loadDefaultCustomer();
  }

  /// Sends items to the server via POST /sales/add/item and returns the
  /// server-side cart response (which includes server-computed totals).
  Future<Map<String, dynamic>?> checkout() async {
    final customer = state.customer;
    if (state.items.isEmpty || customer == null) return null;

    state = state.copyWith(isCheckingOut: true, clearError: true);
    try {
      final golfCourseId =
          _ref.read(authProvider).user?.golfCourse?.id;
      final products =
          state.items.map((item) => item.toCheckoutJson()).toList();

      final result = await _repo.addItemToSales(
        customerId: customer.id,
        golfCourseId: golfCourseId,
        products: products,
        cartState: 'Sale',
      );
      state = state.copyWith(isCheckingOut: false);
      return result;
    } catch (e) {
      state = state.copyWith(
          isCheckingOut: false, error: e.toString());
      return null;
    }
  }

  Future<void> holdCart() async {
    final customer = state.customer;
    if (state.items.isEmpty || customer == null) return;

    try {
      final golfCourseId =
          _ref.read(authProvider).user?.golfCourse?.id;
      final products =
          state.items.map((item) => item.toCheckoutJson()).toList();

      await _repo.holdCart(
        customerId: customer.id,
        golfCourseId: golfCourseId,
        products: products,
      );
      clearCart();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(
    ref.read(posRepositoryProvider),
    ref.read(customerRepositoryProvider),
    ref,
  );
});
