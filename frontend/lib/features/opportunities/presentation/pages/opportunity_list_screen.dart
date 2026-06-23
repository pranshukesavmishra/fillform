import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class OpportunityListScreen extends StatefulWidget {
  const OpportunityListScreen({super.key});
  @override
  State<OpportunityListScreen> createState() => _OpportunityListScreenState();
}

class _OpportunityListScreenState extends State<OpportunityListScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showEligibleOnly = true;

  final List<String> _categories = [
    'All', 'Scholarship', 'Govt Job', 'Admission', 'Fellowship', 'Skill Training',
  ];

  final List<Map<String, dynamic>> _mockOpps = [
    {'title': 'PM Scholarship Scheme 2024', 'category': 'Scholarship', 'amount': '₹36,000', 'deadline': '15 Nov 2024', 'probability': 0.78, 'seats': 5000, 'state': 'All India', 'isNew': true, 'isEligible': true},
    {'title': 'AICTE Pragati Scholarship for Girls', 'category': 'Scholarship', 'amount': '₹50,000', 'deadline': '8 Dec 2024', 'probability': 0.62, 'seats': 4000, 'state': 'All India', 'isNew': true, 'isEligible': true},
    {'title': 'UP Mukhyamantri Fellowship', 'category': 'Fellowship', 'amount': '₹25,000/mo', 'deadline': '30 Nov 2024', 'probability': 0.85, 'seats': 200, 'state': 'Uttar Pradesh', 'isNew': false, 'isEligible': true},
    {'title': 'UPSC CSE 2025', 'category': 'Govt Job', 'amount': 'Grade A', 'deadline': '10 Jan 2025', 'probability': 0.22, 'seats': 1105, 'state': 'All India', 'isNew': false, 'isEligible': false},
    {'title': 'NSP Post-Matric Scholarship', 'category': 'Scholarship', 'amount': '₹10,000', 'deadline': '31 Oct 2024', 'probability': 0.91, 'seats': 50000, 'state': 'All India', 'isNew': false, 'isEligible': true},
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _mockOpps.where((o) {
      if (_showEligibleOnly && !(o['isEligible'] as bool)) return false;
      if (_selectedCategory != 'All' && o['category'] != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty &&
          !o['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover Opportunities', style: AppTextStyles.headlineLarge)
                      .animate().fadeIn().slideX(begin: -0.2),
                  Text(
                    '${filtered.length} matching your profile • Updated 5 min ago',
                    style: AppTextStyles.bodyMedium,
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '🔍  Search scholarships, jobs, admissions...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.verified_outlined,
                          color: _showEligibleOnly ? AppColors.success : AppColors.textMuted,
                        ),
                        tooltip: 'Eligible Only',
                        onPressed: () => setState(() => _showEligibleOnly = !_showEligibleOnly),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_outlined, color: AppColors.textMuted),
                        onPressed: () {},
                        tooltip: 'Filters',
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),
            ),

            const SizedBox(height: AppSpacing.md),

            // Category chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: _categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: AppColors.primary.withOpacity(0.3),
                    checkmarkColor: AppColors.primaryLight,
                    side: BorderSide(
                      color: _selectedCategory == cat
                          ? AppColors.primaryLight
                          : AppColors.divider,
                    ),
                  ),
                )).toList(),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: AppSpacing.lg),

            // Results
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(showEligibleOnly: _showEligibleOnly)
                  : isWide
                      ? _GridView(opportunities: filtered)
                      : _ListView(opportunities: filtered),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  final List<Map<String, dynamic>> opportunities;
  const _ListView({required this.opportunities});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      itemCount: opportunities.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => _OpportunityCard(
        data: opportunities[i],
        index: i,
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  final List<Map<String, dynamic>> opportunities;
  const _GridView({required this.opportunities});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: 1.6,
      ),
      itemCount: opportunities.length,
      itemBuilder: (context, i) => _OpportunityCard(data: opportunities[i], index: i),
    );
  }
}

class _OpportunityCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  const _OpportunityCard({required this.data, required this.index});

  @override
  State<_OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends State<_OpportunityCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final prob = widget.data['probability'] as double;
    final isEligible = widget.data['isEligible'] as bool;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/opportunities/mock-id'),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          child: GlassCard(
            borderColor: isEligible ? AppColors.success : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.data['category'],
                        style: AppTextStyles.caption.copyWith(color: AppColors.primaryLight),
                      ),
                    ),
                    if (widget.data['isNew'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.goldGradient),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('NEW', style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10,
                        )),
                      ),
                    ],
                    const Spacer(),
                    if (isEligible)
                      const Icon(Icons.verified, color: AppColors.success, size: 18),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.data['title'],
                  style: AppTextStyles.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      widget.data['amount'],
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.success, fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(' · ${widget.data['state']}', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    // Deadline
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(widget.data['deadline'], style: AppTextStyles.caption),
                      ],
                    ),
                    const Spacer(),
                    // Success probability
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _probColor(prob).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, size: 12, color: _probColor(prob)),
                          const SizedBox(width: 4),
                          Text(
                            '${(prob * 100).toInt()}% success',
                            style: AppTextStyles.caption.copyWith(
                              color: _probColor(prob), fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 80)).slideY(begin: 0.2);
  }

  Color _probColor(double p) {
    if (p >= 0.7) return AppColors.success;
    if (p >= 0.4) return AppColors.warning;
    return AppColors.error;
  }
}

class _EmptyState extends StatelessWidget {
  final bool showEligibleOnly;
  const _EmptyState({required this.showEligibleOnly});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppSpacing.lg),
          Text('No opportunities found', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            showEligibleOnly
                ? 'Try turning off "Eligible Only" filter'
                : 'Try a different search term',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
