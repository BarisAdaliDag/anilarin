/// Teslimat adresi (Popsa New Address formu, Türkiye alanları).
class Address {
  String country;
  String firstName;
  String lastName;
  String line1;
  String line2;
  String postCode;
  String district;
  String city;
  String phone;

  Address({
    this.country = 'Türkiye',
    this.firstName = '',
    this.lastName = '',
    this.line1 = '',
    this.line2 = '',
    this.postCode = '',
    this.district = '',
    this.city = '',
    this.phone = '',
  });

  String get fullName => '$firstName $lastName'.trim();

  /// Kartlarda gösterilen çok satırlı adres.
  List<String> get lines => [
    fullName,
    line1,
    if (line2.isNotEmpty) line2,
    [postCode, district, city].where((s) => s.isNotEmpty).join(' '),
    country,
    if (phone.isNotEmpty) phone,
  ];

  Map<String, dynamic> toJson() => {
    'country': country,
    'first': firstName,
    'last': lastName,
    'line1': line1,
    'line2': line2,
    'post': postCode,
    'district': district,
    'city': city,
    'phone': phone,
  };

  factory Address.fromJson(Map<String, dynamic> j) => Address(
    country: j['country'] ?? 'Türkiye',
    firstName: j['first'] ?? '',
    lastName: j['last'] ?? '',
    line1: j['line1'] ?? '',
    line2: j['line2'] ?? '',
    postCode: j['post'] ?? '',
    district: j['district'] ?? '',
    city: j['city'] ?? '',
    phone: j['phone'] ?? '',
  );
}

/// Kargo seçeneği. Gün aralığı ürünün teslim süresine eklenir.
class ShippingOption {
  final String id;
  final int priceCents;
  final int extraDaysMin;
  final int extraDaysMax;

  const ShippingOption(this.id, this.priceCents, this.extraDaysMin, this.extraDaysMax);

  // Popsa'daki değerler (TR, Ekim 2026): Standart ₺500, 11 gün sonra 13–19 Kas; Takipli ₺1.250, 11–14 Kas.
  static const standard = ShippingOption('standard', 50000, 4, 5);
  static const tracked = ShippingOption('tracked', 125000, 2, 0);
  static const all = [standard, tracked];

  static ShippingOption byId(String? id) => all.firstWhere((s) => s.id == id, orElse: () => standard);
}
