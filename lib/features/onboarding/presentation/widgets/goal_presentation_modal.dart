import 'package:flutter/material.dart';
import 'package:moneko/features/onboarding/data/models/goal_creation_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:intl/intl.dart';

class GoalPresentationModal extends StatefulWidget {
  final GoalCreationResult goal;
  final VoidCallback onComplete;
  final VoidCallback onClose;

  const GoalPresentationModal({
    super.key,
    required this.goal,
    required this.onComplete,
    required this.onClose,
  });

  @override
  State<GoalPresentationModal> createState() => _GoalPresentationModalState();
}

class _GoalPresentationModalState extends State<GoalPresentationModal> {
  int currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (currentPage < 2) {
      _pageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _previousPage() {
    if (currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: shadcnui.Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: shadcnui.Theme.of(context).colorScheme.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Financial Goal',
                        style: shadcnui.Theme.of(context).typography.h3,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // Page indicator
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: currentPage == index
                            ? shadcnui.Theme.of(context).colorScheme.primary
                            : shadcnui.Theme.of(context).colorScheme.muted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // Body
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  children: [
                    _buildSummaryPage(context),
                    _buildInsightsPage(context),
                    _buildNextStepsPage(context),
                  ],
                ),
              ),

              // Navigation buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: shadcnui.Theme.of(context).colorScheme.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousPage,
                          child: const Text('Previous'),
                        ),
                      ),
                    if (currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      child: shadcnui.PrimaryButton(
                        onPressed: _nextPage,
                        child: Text(
                          currentPage == 2 ? 'Get Started' : 'Next',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPage(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal icon/illustration
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: shadcnui.Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag,
                size: 40,
                color: shadcnui.Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            widget.goal.goalName,
            style: shadcnui.Theme.of(context).typography.h1,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          _buildInfoCard(
            context,
            'Target Amount',
            currencyFormat.format(widget.goal.targetAmount),
            Icons.attach_money,
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            'Target Date',
            dateFormat.format(widget.goal.targetDate),
            Icons.calendar_today,
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            'Goal Type',
            widget.goal.goalType,
            Icons.category,
          ),

          if (widget.goal.description != null) ...[
            const SizedBox(height: 24),
            Text(
              'Description',
              style: shadcnui.Theme.of(context).typography.h4,
            ),
            const SizedBox(height: 8),
            Text(
              widget.goal.description!,
              style: shadcnui.Theme.of(context).typography.textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsPage(BuildContext context) {
    final insights = widget.goal.keyInsights ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Insights',
            style: shadcnui.Theme.of(context).typography.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your financial profile, here are some important insights',
            style: shadcnui.Theme.of(context).typography.textMuted,
          ),
          const SizedBox(height: 24),

          if (insights.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No insights available at this time',
                  style: shadcnui.Theme.of(context).typography.textMuted,
                ),
              ),
            )
          else
            ...insights.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildInsightCard(context, entry.key + 1, entry.value),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildNextStepsPage(BuildContext context) {
    final nextSteps = widget.goal.nextSteps ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Steps',
            style: shadcnui.Theme.of(context).typography.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s your action plan to achieve your financial goal',
            style: shadcnui.Theme.of(context).typography.textMuted,
          ),
          const SizedBox(height: 24),

          if (nextSteps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No action steps available at this time',
                  style: shadcnui.Theme.of(context).typography.textMuted,
                ),
              ),
            )
          else
            ...nextSteps.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildStepCard(context, entry.key + 1, entry.value),
              );
            }).toList(),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: shadcnui.Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: shadcnui.Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.rocket_launch,
                  size: 48,
                  color: shadcnui.Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ready to get started?',
                  style: shadcnui.Theme.of(context).typography.h4,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your personalized financial plan is ready. Click "Get Started" to begin your journey!',
                  style: shadcnui.Theme.of(context).typography.textMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shadcnui.Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shadcnui.Theme.of(context).colorScheme.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: shadcnui.Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: shadcnui.Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: shadcnui.Theme.of(context).typography.textMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: shadcnui.Theme.of(context).typography.h4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, int number, String insight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shadcnui.Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shadcnui.Theme.of(context).colorScheme.border,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: shadcnui.Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: shadcnui.Theme.of(context).typography.small.copyWith(
                  color: shadcnui.Theme.of(context).colorScheme.primaryForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight,
              style: shadcnui.Theme.of(context).typography.small,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, int number, String step) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shadcnui.Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shadcnui.Theme.of(context).colorScheme.border,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF16CDA2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: shadcnui.Theme.of(context).typography.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step,
              style: shadcnui.Theme.of(context).typography.small,
            ),
          ),
        ],
      ),
    );
  }
}
