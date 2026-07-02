class UserModel {
  final String id;
  final String? fullName;
  final String phone;
  final String? email;
  final String? state;
  final String? district;
  final String? category;
  final String? educationLevel;
  final double? marks12thPercent;
  final int? familyIncomeAnnual;
  final String? careerGoal;
  final List<String> skills;
  final String preferredLanguage;
  final bool whatsappOptedIn;
  final double completeness;

  const UserModel({
    required this.id,
    this.fullName,
    required this.phone,
    this.email,
    this.state,
    this.district,
    this.category,
    this.educationLevel,
    this.marks12thPercent,
    this.familyIncomeAnnual,
    this.careerGoal,
    this.skills = const [],
    this.preferredLanguage = 'hi',
    this.whatsappOptedIn = true,
    this.completeness = 0.0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? json;
    return UserModel(
      id: profile['id']?.toString() ?? '',
      fullName: profile['full_name'] as String?,
      phone: profile['phone'] as String? ?? '',
      email: profile['email'] as String?,
      state: profile['state'] as String?,
      district: profile['district'] as String?,
      category: profile['category'] as String?,
      educationLevel: profile['education_level'] as String?,
      marks12thPercent: (profile['marks_12th_percent'] as num?)?.toDouble(),
      familyIncomeAnnual: profile['family_income_annual'] as int?,
      careerGoal: profile['career_goal'] as String?,
      skills: (profile['skills'] as List<dynamic>?)?.cast<String>() ?? [],
      preferredLanguage: profile['preferred_language'] as String? ?? 'hi',
      whatsappOptedIn: profile['whatsapp_opted_in'] as bool? ?? true,
      completeness: (json['completeness'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> get careerDna => {
    'user_id': id,
    'full_name': fullName,
    'state': state,
    'district': district,
    'category': category,
    'education_level': educationLevel,
    'marks_12th_percent': marks12thPercent,
    'family_income_annual': familyIncomeAnnual,
    'career_goal': careerGoal,
    'skills': skills,
    'preferred_language': preferredLanguage,
  };

  String get displayName => fullName ?? phone;
}
