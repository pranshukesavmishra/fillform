class ApplicationModel {
  final String id;
  final String status;
  final String? registrationNumber;
  final String? submittedAt;
  final String? outcomeDate;
  final String? rejectionReason;
  final String opportunityId;
  final String opportunityTitle;
  final String? opportunityCategory;
  final int? opportunityAmount;

  const ApplicationModel({
    required this.id,
    required this.status,
    this.registrationNumber,
    this.submittedAt,
    this.outcomeDate,
    this.rejectionReason,
    required this.opportunityId,
    required this.opportunityTitle,
    this.opportunityCategory,
    this.opportunityAmount,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final opp = json['opportunity'] as Map<String, dynamic>? ?? {};
    return ApplicationModel(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? 'draft',
      registrationNumber: json['registration_number'] as String?,
      submittedAt: json['submitted_at'] as String?,
      outcomeDate: json['outcome_date'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      opportunityId: opp['id']?.toString() ?? json['opportunity_id']?.toString() ?? '',
      opportunityTitle: opp['title'] as String? ?? json['opportunity_title'] as String? ?? '',
      opportunityCategory: opp['category'] as String?,
      opportunityAmount: opp['amount'] as int?,
    );
  }

  bool get isActive => ['submitted', 'under_review', 'draft'].contains(status);
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusLabel {
    const labels = {
      'draft': 'Draft',
      'submitted': 'Submitted',
      'under_review': 'Under Review',
      'approved': 'Approved ✓',
      'rejected': 'Rejected',
      'on_hold': 'On Hold',
      'withdrawn': 'Withdrawn',
    };
    return labels[status] ?? status;
  }
}
