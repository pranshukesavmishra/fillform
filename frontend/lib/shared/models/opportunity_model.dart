class OpportunityModel {
  final String id;
  final String title;
  final String category;
  final String? description;
  final double? amountMin;
  final double? amountMax;
  final String? deadline;
  final String? issuingAuthority;
  final String? portalUrl;
  final bool isVerified;
  final Map<String, dynamic> eligibilityRules;
  final List<String> tags;

  const OpportunityModel({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.amountMin,
    this.amountMax,
    this.deadline,
    this.issuingAuthority,
    this.portalUrl,
    this.isVerified = false,
    this.eligibilityRules = const {},
    this.tags = const [],
  });

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'scholarship',
      description: json['short_description'] as String?,
      amountMin: (json['amount_min'] as num?)?.toDouble(),
      amountMax: (json['amount_max'] as num?)?.toDouble(),
      deadline: json['deadline'] as String?,
      issuingAuthority: json['issuing_authority'] as String?,
      portalUrl: json['portal_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      eligibilityRules: (json['eligibility_rules'] as Map<String, dynamic>?) ?? const {},
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  String? get state {
    final states = eligibilityRules['states_allowed'];
    if (states is List && states.isNotEmpty) return states.first as String?;
    return null;
  }

  String get amountDisplay {
    final amount = amountMax ?? amountMin;
    if (amount == null) return 'Variable';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(0)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  String get categoryLabel {
    const labels = {
      'scholarship': 'Scholarship',
      'government_job': 'Govt Job',
      'internship': 'Internship',
      'loan': 'Loan',
      'skill_program': 'Skill Program',
    };
    return labels[category] ?? category;
  }
}
