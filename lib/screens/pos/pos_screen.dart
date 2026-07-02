import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/pos_provider.dart';
import 'widgets/product_card.dart';
import 'widgets/cart_section.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(departmentsProvider.future).then((depts) {
        if (depts.isNotEmpty && ref.read(selectedDepartmentProvider) == null) {
          ref.read(selectedDepartmentProvider.notifier).state = depts.first.name;
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider).items;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 32,
        title: const Text('Sales Cart', style: TextStyle(fontSize: 15)),
        actions: [
          if (!isWide)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => _showCartSheet(context),
                ),
                if (cartItems.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${cartItems.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 3, child: _ProductsPanel(searchCtrl: _searchCtrl)),
                SizedBox(
                  width: 300,
                  child: const CartSection(),
                ),
              ],
            )
          : _ProductsPanel(searchCtrl: _searchCtrl),
    );
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => const CartSection(),
      ),
    );
  }
}

class _ProductsPanel extends ConsumerStatefulWidget {
  final TextEditingController searchCtrl;
  const _ProductsPanel({required this.searchCtrl});

  @override
  ConsumerState<_ProductsPanel> createState() => _ProductsPanelState();
}

class _ProductsPanelState extends ConsumerState<_ProductsPanel> {
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);
    final selectedDept = ref.watch(selectedDepartmentProvider);
    final labelsAsync = ref.watch(labelsProvider);
    final selectedLabel = ref.watch(selectedLabelProvider);

    return Column(
      children: [
        // Search bar with focus animation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: _searchFocused
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: TextFormField(
              controller: widget.searchCtrl,
              focusNode: _searchFocus,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              ),
              onChanged: (v) {
                ref.read(productSearchProvider.notifier).state = v;
              },
            ),
          ),
        ),

        // Department tabs
        deptsAsync.when(
          loading: () => const SizedBox(height: 32, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
          error: (_, __) => const SizedBox.shrink(),
          data: (depts) => SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              itemCount: depts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final dept = depts[i];
                final isSelected = selectedDept == dept.name;
                return _PressableChip(
                  onTap: () {
                    ref.read(selectedDepartmentProvider.notifier).state = dept.name;
                    ref.read(selectedLabelProvider.notifier).state = null;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        child: Text(dept.name),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Label/filter tabs
        labelsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (labels) {
            if (labels.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 26,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                itemCount: labels.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    final isAll = selectedLabel == null;
                    return _LabelChip(
                      label: 'All',
                      isSelected: isAll,
                      onTap: () => ref.read(selectedLabelProvider.notifier).state = null,
                    );
                  }
                  final label = labels[i - 1];
                  final isSel = selectedLabel == label.id;
                  return _LabelChip(
                    label: label.name,
                    isSelected: isSel,
                    onTap: () => ref.read(selectedLabelProvider.notifier).state = label.id,
                  );
                },
              ),
            );
          },
        ),

        // Products grid
        Expanded(child: _ProductsGrid()),
      ],
    );
  }
}

class _PressableChip extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableChip({required this.child, required this.onTap});

  @override
  State<_PressableChip> createState() => _PressableChipState();
}

class _PressableChipState extends State<_PressableChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

class _LabelChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _LabelChip({required this.label, required this.isSelected, required this.onTap});

  @override
  State<_LabelChip> createState() => _LabelChipState();
}

class _LabelChipState extends State<_LabelChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: widget.isSelected ? AppColors.primary : AppColors.textMuted,
                fontSize: 12,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1.3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 15,
        itemBuilder: (_, __) => const _ShimmerCard(),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 8),
            Text('Failed to load products', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.border),
                  SizedBox(height: 8),
                  Text('No products found', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1.3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(
            product: products[i],
            onTap: () {
              ref.read(cartProvider.notifier).addProduct(products[i]);
              _showAddedSnack(context, products[i].name, 1);
            },
            onAddMultiple: (qty) {
              for (int k = 0; k < qty; k++) {
                ref.read(cartProvider.notifier).addProduct(products[i]);
              }
              _showAddedSnack(context, products[i].name, qty);
            },
          ),
        );
      },
    );
  }

  void _showAddedSnack(BuildContext context, String name, int qty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(qty > 1 ? '$name ×$qty added to cart' : '$name added to cart'),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
      ));
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
