class Country {
  final String code;
  final String name;
  final String nameAr;
  final String dialCode;
  final String flag;

  const Country({
    required this.code,
    required this.name,
    required this.nameAr,
    required this.dialCode,
    required this.flag,
  });

  static const List<Country> countries = [
    Country(
      code: 'SD',
      name: 'Sudan',
      nameAr: 'السودان',
      dialCode: '+249',
      flag: '🇸🇩',
    ),
    Country(
      code: 'SA',
      name: 'Saudi Arabia',
      nameAr: 'السعودية',
      dialCode: '+966',
      flag: '🇸🇦',
    ),
    Country(
      code: 'AE',
      name: 'United Arab Emirates',
      nameAr: 'الإمارات',
      dialCode: '+971',
      flag: '🇦🇪',
    ),
    Country(
      code: 'QA',
      name: 'Qatar',
      nameAr: 'قطر',
      dialCode: '+974',
      flag: '🇶🇦',
    ),
    Country(
      code: 'EG',
      name: 'Egypt',
      nameAr: 'مصر',
      dialCode: '+20',
      flag: '🇪🇬',
    ),
    Country(
      code: 'TR',
      name: 'Turkey',
      nameAr: 'تركيا',
      dialCode: '+90',
      flag: '🇹🇷',
    ),
    Country(
      code: 'KW',
      name: 'Kuwait',
      nameAr: 'الكويت',
      dialCode: '+965',
      flag: '🇰🇼',
    ),
    Country(
      code: 'BH',
      name: 'Bahrain',
      nameAr: 'البحرين',
      dialCode: '+973',
      flag: '🇧🇭',
    ),
    Country(
      code: 'OM',
      name: 'Oman',
      nameAr: 'عمان',
      dialCode: '+968',
      flag: '🇴🇲',
    ),
    Country(
      code: 'JO',
      name: 'Jordan',
      nameAr: 'الأردن',
      dialCode: '+962',
      flag: '🇯🇴',
    ),
    Country(
      code: 'LB',
      name: 'Lebanon',
      nameAr: 'لبنان',
      dialCode: '+961',
      flag: '🇱🇧',
    ),
    Country(
      code: 'SY',
      name: 'Syria',
      nameAr: 'سوريا',
      dialCode: '+963',
      flag: '🇸🇾',
    ),
    Country(
      code: 'IQ',
      name: 'Iraq',
      nameAr: 'العراق',
      dialCode: '+964',
      flag: '🇮🇶',
    ),
    Country(
      code: 'LY',
      name: 'Libya',
      nameAr: 'ليبيا',
      dialCode: '+218',
      flag: '🇱🇾',
    ),
    Country(
      code: 'TN',
      name: 'Tunisia',
      nameAr: 'تونس',
      dialCode: '+216',
      flag: '🇹🇳',
    ),
    Country(
      code: 'DZ',
      name: 'Algeria',
      nameAr: 'الجزائر',
      dialCode: '+213',
      flag: '🇩🇿',
    ),
    Country(
      code: 'MA',
      name: 'Morocco',
      nameAr: 'المغرب',
      dialCode: '+212',
      flag: '🇲🇦',
    ),
    Country(
      code: 'YE',
      name: 'Yemen',
      nameAr: 'اليمن',
      dialCode: '+967',
      flag: '🇾🇪',
    ),
    Country(
      code: 'PS',
      name: 'Palestine',
      nameAr: 'فلسطين',
      dialCode: '+970',
      flag: '🇵🇸',
    ),
    Country(
      code: 'US',
      name: 'United States',
      nameAr: 'الولايات المتحدة',
      dialCode: '+1',
      flag: '🇺🇸',
    ),
    Country(
      code: 'GB',
      name: 'United Kingdom',
      nameAr: 'بريطانيا',
      dialCode: '+44',
      flag: '🇬🇧',
    ),
    Country(
      code: 'CA',
      name: 'Canada',
      nameAr: 'كندا',
      dialCode: '+1',
      flag: '🇨🇦',
    ),
    Country(
      code: 'AU',
      name: 'Australia',
      nameAr: 'أستراليا',
      dialCode: '+61',
      flag: '🇦🇺',
    ),
    Country(
      code: 'DE',
      name: 'Germany',
      nameAr: 'ألمانيا',
      dialCode: '+49',
      flag: '🇩🇪',
    ),
    Country(
      code: 'FR',
      name: 'France',
      nameAr: 'فرنسا',
      dialCode: '+33',
      flag: '🇫🇷',
    ),
    Country(
      code: 'IT',
      name: 'Italy',
      nameAr: 'إيطاليا',
      dialCode: '+39',
      flag: '🇮🇹',
    ),
    Country(
      code: 'ES',
      name: 'Spain',
      nameAr: 'إسبانيا',
      dialCode: '+34',
      flag: '🇪🇸',
    ),
    Country(
      code: 'RU',
      name: 'Russia',
      nameAr: 'روسيا',
      dialCode: '+7',
      flag: '🇷🇺',
    ),
    Country(
      code: 'CN',
      name: 'China',
      nameAr: 'الصين',
      dialCode: '+86',
      flag: '🇨🇳',
    ),
    Country(
      code: 'JP',
      name: 'Japan',
      nameAr: 'اليابان',
      dialCode: '+81',
      flag: '🇯🇵',
    ),
    Country(
      code: 'IN',
      name: 'India',
      nameAr: 'الهند',
      dialCode: '+91',
      flag: '🇮🇳',
    ),
    Country(
      code: 'PK',
      name: 'Pakistan',
      nameAr: 'باكستان',
      dialCode: '+92',
      flag: '🇵🇰',
    ),
    Country(
      code: 'BD',
      name: 'Bangladesh',
      nameAr: 'بنغلاديش',
      dialCode: '+880',
      flag: '🇧🇩',
    ),
    Country(
      code: 'NG',
      name: 'Nigeria',
      nameAr: 'نيجيريا',
      dialCode: '+234',
      flag: '🇳🇬',
    ),
    Country(
      code: 'KE',
      name: 'Kenya',
      nameAr: 'كينيا',
      dialCode: '+254',
      flag: '🇰🇪',
    ),
    Country(
      code: 'ET',
      name: 'Ethiopia',
      nameAr: 'إثيوبيا',
      dialCode: '+251',
      flag: '🇪🇹',
    ),
    Country(
      code: 'UG',
      name: 'Uganda',
      nameAr: 'أوغندا',
      dialCode: '+256',
      flag: '🇺🇬',
    ),
    Country(
      code: 'TZ',
      name: 'Tanzania',
      nameAr: 'تنزانيا',
      dialCode: '+255',
      flag: '🇹🇿',
    ),
    Country(
      code: 'ZA',
      name: 'South Africa',
      nameAr: 'جنوب أفريقيا',
      dialCode: '+27',
      flag: '🇿🇦',
    ),
  ];

  static Country getCountryByCode(String code) {
    return countries.firstWhere(
      (country) => country.code == code,
      orElse: () => countries.first, // Default to Sudan
    );
  }

  static Country getCountryByDialCode(String dialCode) {
    return countries.firstWhere(
      (country) => country.dialCode == dialCode,
      orElse: () => countries.first, // Default to Sudan
    );
  }
}
