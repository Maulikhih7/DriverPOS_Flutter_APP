import 'package:flutter/material.dart';

class CustomerFeeSet {
  final double greenFee;
  final double cartFee;
  final double greenFeeTax;
  final double cartFeeTax;
  final double total;
  final double taxAmount;

  const CustomerFeeSet({
    this.greenFee = 0,
    this.cartFee = 0,
    this.greenFeeTax = 0,
    this.cartFeeTax = 0,
    this.total = 0,
    this.taxAmount = 0,
  });

  factory CustomerFeeSet.fromJson(Map<String, dynamic> json) {
    return CustomerFeeSet(
      greenFee: (json['greenFee'] as num?)?.toDouble() ?? 0,
      cartFee: (json['cartFee'] as num?)?.toDouble() ?? 0,
      greenFeeTax: (json['greenFeeTax'] as num?)?.toDouble() ?? 0,
      cartFeeTax: (json['cartFeeTax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CustomerSuggestion {
  final String id;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? membershipType;
  final CustomerFeeSet nineHole;
  final CustomerFeeSet eighteenHole;

  const CustomerSuggestion({
    required this.id,
    required this.fullName,
    this.email,
    this.phoneNumber,
    this.membershipType,
    required this.nineHole,
    required this.eighteenHole,
  });

  CustomerFeeSet feesForHoles(int holes) =>
      holes == 9 ? nineHole : eighteenHole;

  factory CustomerSuggestion.fromJson(Map<String, dynamic> json) {
    return CustomerSuggestion(
      id: json['_id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      membershipType: json['membershipType']?.toString(),
      nineHole: CustomerFeeSet.fromJson(
        json['nineHole'] as Map<String, dynamic>? ?? {},
      ),
      eighteenHole: CustomerFeeSet.fromJson(
        json['eighteenHole'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class TeeSheetInfo {
  final String id;
  final String name;
  final String? golfCourseName;
  final String? golfCourseId;
  final List<int> holes;

  const TeeSheetInfo({
    required this.id,
    required this.name,
    this.golfCourseName,
    this.golfCourseId,
    this.holes = const [9, 18],
  });

  factory TeeSheetInfo.fromJson(Map<String, dynamic> json) {
    final gc = json['golfCourse'];
    final rawHoles = json['holes'];
    final holesList = rawHoles is List
        ? rawHoles.map((h) => (h as num).toInt()).toList()
        : [9, 18];
    return TeeSheetInfo(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      golfCourseName: gc is Map ? gc['name']?.toString() : gc?.toString(),
      golfCourseId: gc is Map ? (gc['_id'] ?? gc['id'])?.toString() : null,
      holes: holesList,
    );
  }
}

class TeeTimeRow {
  final String time;
  final int count;
  final int frontCount;
  final int backCount;
  final bool isBlock;
  final String? blockName;
  final List<TeeSlotEntry> frontBooking;
  final List<TeeSlotEntry> backBooking;

  const TeeTimeRow({
    required this.time,
    this.count = 0,
    this.frontCount = 0,
    this.backCount = 0,
    this.isBlock = false,
    this.blockName,
    this.frontBooking = const [],
    this.backBooking = const [],
  });

  bool get isEmpty => frontBooking.isEmpty;

  factory TeeTimeRow.fromJson(Map<String, dynamic> json) {
    final frontBooking =
        (json['frontBooking'] as List?)
            ?.map((e) => TeeSlotEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final backBooking =
        (json['backBooking'] as List?)
            ?.map((e) => TeeSlotEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return TeeTimeRow(
      time: json['time']?.toString() ?? '',
      count:
          (json['count'] as num?)?.toInt() ??
          (frontBooking.length + backBooking.length),
      frontCount:
          (json['frontCount'] as num?)?.toInt() ??
          frontBooking.fold(0, (s, e) => s + e.customerCount),
      backCount:
          (json['backCount'] as num?)?.toInt() ??
          backBooking.fold(0, (s, e) => s + e.customerCount),
      isBlock: json['isBlock'] == true,
      blockName: json['blockName']?.toString(),
      frontBooking: frontBooking,
      backBooking: backBooking,
    );
  }
}

class TeeSlotEntry {
  final String? docId;
  final String slotId;
  final String? groupId;
  final String? customerId;
  final String customer;
  final int customerCount;
  final int holes;
  final bool checkedIn;
  final bool noshow;
  final bool split;
  final String status;
  final bool isPending;

  // Capsule styling + status icons — sent directly by the backend
  // (helper/teeSheetHelper.js `formatIndividualBookingForFront`/combined
  // builders) so the app should consume these rather than re-deriving
  // status colors locally.
  //
  // For a combined (non-split, multi-customer-per-slot — the default)
  // booking, `bgColor` is a CSS `linear-gradient(to right, ...)` string
  // representing the % mix of statuses across all customers in the group
  // (e.g. half paid/half unpaid) — not a plain hex. `bgGradient` holds the
  // parsed version of that; `bgColor` is only set when it's a plain hex
  // (the simpler "individual"/split booking case).
  final Color? bgColor;
  final Gradient? bgGradient;
  final Color? badgeColor;
  // The web shows the cart icon based on `carts` (a count) being > 0, not
  // on `assignedCart` — that's just optional label text from cartOne/
  // cartTwo and can be empty even when a cart genuinely was requested.
  final int carts;
  final String? assignedCart;
  final bool handicap;
  final bool rentalClubs;
  final bool rainCheck;
  final bool isPreAuth;
  final bool preventNoshow;
  final bool onlineBook;

  const TeeSlotEntry({
    this.docId,
    required this.slotId,
    this.groupId,
    this.customerId,
    required this.customer,
    this.customerCount = 1,
    this.holes = 18,
    this.checkedIn = false,
    this.noshow = false,
    this.split = false,
    this.status = 'Reserve',
    this.isPending = false,
    this.bgColor,
    this.bgGradient,
    this.badgeColor,
    this.carts = 0,
    this.assignedCart,
    this.handicap = false,
    this.rentalClubs = false,
    this.rainCheck = false,
    this.isPreAuth = false,
    this.preventNoshow = false,
    this.onlineBook = false,
  });

  factory TeeSlotEntry.fromJson(Map<String, dynamic> json) {
    return TeeSlotEntry(
      docId: json['_id']?.toString(),
      slotId: json['slotId']?.toString() ?? '',
      groupId: json['groupId']?.toString(),
      customerId: json['customerId']?.toString(),
      customer: json['customer']?.toString() ?? 'Guest',
      customerCount: (json['customerCount'] as num?)?.toInt() ?? 1,
      holes: (json['holes'] as num?)?.toInt() ?? 18,
      checkedIn: json['checkedIn'] == true,
      noshow: json['noshow'] == true,
      split: json['split'] == true,
      status: json['status']?.toString() ?? 'Reserve',
      isPending: json['isPending'] == true,
      bgColor: _hexColor(json['bgColor']),
      bgGradient: _cssGradient(json['bgColor']),
      badgeColor: _hexColor(json['color']),
      carts: (json['carts'] as num?)?.toInt() ?? 0,
      assignedCart: (json['assignedCart'] as String?)?.trim().isNotEmpty == true
          ? json['assignedCart'] as String
          : null,
      handicap: json['handicap'] == true,
      rentalClubs: json['rentalClubs'] == true,
      rainCheck: json['rainCheck'] == true,
      isPreAuth: json['isPreAuth'] == true,
      preventNoshow: json['preventNoshow'] == true,
      onlineBook: json['onlineBook'] == true,
    );
  }

  static Color? _hexColor(dynamic raw) {
    if (raw is! String) return null;
    final hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    return null;
  }

  /// Parses the backend's `linear-gradient(to right, #hex p1%, #hex p2%, ...)`
  /// string (helper/teeSheetHelper.js `determineBgColorforCombined`) into a
  /// Flutter LinearGradient with matching color stops, left-to-right.
  static Gradient? _cssGradient(dynamic raw) {
    if (raw is! String || !raw.trim().startsWith('linear-gradient')) {
      return null;
    }
    final inner = raw.trim().replaceFirst('linear-gradient(', '');
    final body = inner.endsWith(')')
        ? inner.substring(0, inner.length - 1)
        : inner;
    final parts = body.split(',').map((p) => p.trim()).toList();
    if (parts.isNotEmpty && parts.first.startsWith('to ')) parts.removeAt(0);

    final colors = <Color>[];
    final stops = <double>[];
    for (final part in parts) {
      final tokens = part.split(RegExp(r'\s+'));
      if (tokens.length < 2) continue;
      final color = _hexColor(tokens[0]);
      final pct = double.tryParse(tokens[1].replaceAll('%', ''));
      if (color == null || pct == null) continue;
      colors.add(color);
      stops.add((pct / 100).clamp(0.0, 1.0));
    }
    if (colors.isEmpty) return null;
    if (colors.length == 1)
      return null; // degenerate — let the plain hex path handle it

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: colors,
      stops: stops,
    );
  }
}

// ---------------------------------------------------------------------------
// Slot detail (fetched via GET /teesheet/book/:slotId)
// ---------------------------------------------------------------------------

class SlotCustomer {
  final String? docId;
  final String? customerId;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? membershipType;
  final bool checkedIn;
  final bool noshow;
  final bool isGuest;
  final double amount;
  final double taxAmount;
  final double greenFee;
  final double cartFee;
  final double greenFeeTax;
  final double cartFeeTax;
  final bool cartNeeded;
  final bool handicap;
  final bool rentalClubs;
  final int holes;
  final String? slotId;
  final bool preventNoshow;
  final String transaction; // "Unpaid" | "Paid"

  const SlotCustomer({
    this.docId,
    this.customerId,
    required this.fullName,
    this.email,
    this.phoneNumber,
    this.membershipType,
    this.checkedIn = false,
    this.noshow = false,
    this.isGuest = false,
    this.amount = 0,
    this.taxAmount = 0,
    this.greenFee = 0,
    this.cartFee = 0,
    this.greenFeeTax = 0,
    this.cartFeeTax = 0,
    this.cartNeeded = false,
    this.handicap = false,
    this.rentalClubs = false,
    this.holes = 18,
    this.slotId,
    this.preventNoshow = false,
    this.transaction = 'Unpaid',
  });

  factory SlotCustomer.fromJson(Map<String, dynamic> json) {
    // customerId may come back as an object (populated) or string
    final cidRaw = json['customerId'];
    final cid = cidRaw is Map
        ? (cidRaw['_id'] ?? cidRaw['id'])?.toString()
        : cidRaw?.toString();

    return SlotCustomer(
      docId: json['docId']?.toString() ?? json['_id']?.toString(),
      customerId: cid,
      fullName: json['fullName']?.toString() ?? 'Guest',
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      membershipType: (json['membership'] is Map)
          ? (json['membership'] as Map)['name']?.toString()
          : json['membershipType']?.toString(),
      checkedIn: json['checkedIn'] == true,
      noshow: json['noshow'] == true,
      isGuest: json['isGuest'] == true,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      greenFee: (json['greenFee'] as num?)?.toDouble() ?? 0,
      cartFee: (json['cartFee'] as num?)?.toDouble() ?? 0,
      greenFeeTax: (json['greenFeeTax'] as num?)?.toDouble() ?? 0,
      cartFeeTax: (json['cartFeeTax'] as num?)?.toDouble() ?? 0,
      cartNeeded: json['cartNeeded'] == true,
      handicap: json['handicap'] == true,
      rentalClubs: json['rentalClubs'] == true,
      holes: (json['holes'] as num?)?.toInt() ?? 18,
      slotId: json['slotId']?.toString(),
      preventNoshow: json['preventNoshow'] == true,
      transaction: json['transaction']?.toString() ?? 'Unpaid',
    );
  }
}

class SlotDetail {
  final String slotId;
  final String? groupId;
  final String? golfCourseId;
  final String? teesheetId;
  final String startingSlot;
  final int persons;
  final int personPerSlot;
  final int carts;
  final int holes;
  final String? cartOne;
  final String? cartTwo;
  final String? notes;
  final bool split;
  final bool checkedIn;
  final bool teeOff;
  final bool turn;
  final bool complete;
  final bool rainCheck;
  final String booking;
  final List<SlotCustomer> customers;

  const SlotDetail({
    required this.slotId,
    this.groupId,
    this.golfCourseId,
    this.teesheetId,
    required this.startingSlot,
    this.persons = 1,
    this.personPerSlot = 4,
    this.carts = 0,
    this.holes = 18,
    this.cartOne,
    this.cartTwo,
    this.notes,
    this.split = false,
    this.checkedIn = false,
    this.teeOff = false,
    this.turn = false,
    this.complete = false,
    this.rainCheck = false,
    this.booking = 'Reserve',
    this.customers = const [],
  });

  factory SlotDetail.fromJson(Map<String, dynamic> json) {
    return SlotDetail(
      slotId: json['slotId']?.toString() ?? '',
      groupId: json['groupId']?.toString(),
      golfCourseId: json['golfCourse']?.toString(),
      teesheetId: json['teesheet']?.toString(),
      startingSlot: json['startingSlot']?.toString() ?? '',
      persons: (json['persons'] as num?)?.toInt() ?? 1,
      personPerSlot: (json['personPerSlot'] as num?)?.toInt() ?? 4,
      carts: (json['carts'] as num?)?.toInt() ?? 0,
      holes: (json['holes'] as num?)?.toInt() ?? 18,
      cartOne: json['cartOne']?.toString(),
      cartTwo: json['cartTwo']?.toString(),
      notes: json['notes']?.toString(),
      split: json['split'] == true,
      checkedIn: json['checkedIn'] == true,
      teeOff: json['teeOff'] == true,
      turn: json['turn'] == true,
      complete: json['complete'] == true,
      rainCheck: json['rainCheck'] == true,
      booking: json['booking']?.toString() ?? 'Reserve',
      customers:
          (json['customers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(SlotCustomer.fromJson)
              .toList() ??
          [],
    );
  }
}
