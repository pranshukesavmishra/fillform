class OpportunityModel {
  final String id;
  final String title;
  final String category;
  final String? description;
  final int? amount;
  final String? deadline;
  final String? issuingAuthority;
  final String? portalUrl;
  final double? successProbability;
  final bool isBookmarked;
  final List<String> eligibilitySummary;
  final String? state;
  final String? level;

  const OpportunityModel({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.amount,
    this.deadline,
    this.issuingAuthority,
    this.portalUrl,
    this.successProbability,
    this.isBookmarked = false,
    this.eligibilitySummary = const [],
    this.state,
    this.level,
  });

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'scholarship',
      description: json['description'] as String?,
      amount: json['amount'] as int?,
      deadline: json['deadline'] as String?,
      issuingAuthority: json['issuing_authority'] as String?,
      portalUrl: json['portal_url'] as String?,
      successProbability: (json['success_probability'] as num?)?.toDouble(),
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      eligibilitySummary: (json['eligibility_summary'] as List<dynamic>?)?.cast<String>() ?? [],
      state: json['state'] as String?,
      level: json['level'] as String?,
    );
  }

  String get amountDisplay {
    if (amount == null) return 'Variable';
    if (amount! >= 100000) return '₹${(amount! / 100000).toStringAsFixed(1)}L/year';
    if (amount! >= 1000) return '₹${(amount! / 1000).toStringAsFixed(0)}K/year';
    return '₹$amount/year';
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
