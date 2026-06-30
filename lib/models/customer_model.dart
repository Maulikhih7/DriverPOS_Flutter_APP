class CustomerGiftCard {
  final String number;
  final double amount;
  final String? expiryDate;

  const CustomerGiftCard({required this.number, required this.amount, this.expiryDate});

  factory CustomerGiftCard.fromJson(Map<String, dynamic> json) {
    return CustomerGiftCard(
      number: (json['number'] ?? json['cardNumber'] ?? '').toString(),
      amount: _toDouble(json['amount'] ?? json['balance'] ?? 0),
      expiryDate: json['expiryDate']?.toString(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

class CustomerModel {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? profileImage;
  final double? storeCredit;
  final String? membershipType;
  final DateTime? createdAt;
  final List<CustomerGiftCard> giftCards;

  const CustomerModel({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.profileImage,
    this.storeCredit,
    this.membershipType,
    this.createdAt,
    this.giftCards = const [],
  });

  String get fullName {
    final parts = [firstName, lastName].where((p) => p != null && p.isNotEmpty);
    return parts.join(' ').trim().isEmpty ? 'Guest' : parts.join(' ');
  }

  String get initials {
    final f = (firstName?.isNotEmpty == true) ? firstName![0].toUpperCase() : '';
    final l = (lastName?.isNotEmpty == true) ? lastName![0].toUpperCase() : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['_id'] ?? json['id'] ?? '',
      firstName: json['firstName'] ?? json['fname'] ?? json['name'],
      lastName: json['lastName'] ?? json['lname'],
      email: json['email'],
      phone: json['phone'] ?? json['phoneNumber'],
      profileImage: json['profileImage'],
      storeCredit: _toDouble(json['storeCredit']),
      membershipType: json['membershipType'] is Map
          ? json['membershipType']['name']
          : json['membershipType'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      giftCards: (json['giftCard'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(CustomerGiftCard.fromJson)
              .where((g) => g.number.isNotEmpty)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'profileImage': profileImage,
    'storeCredit': storeCredit,
  };

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
