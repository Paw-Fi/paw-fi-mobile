import 'package:flutter/material.dart';

import '../widgets/onboarding_card.dart';
import 'household_create_page.dart';
import 'household_join_page.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/theme/app_theme.dart';


/// Full-page household onboarding with flashcard carousel
class HouseholdOnboardingPage extends StatefulWidget {
  const HouseholdOnboardingPage({super.key});

  @override
  State<HouseholdOnboardingPage> createState() => _HouseholdOnboardingPageState();
}

class _HouseholdOnboardingPageState extends State<HouseholdOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.background,
      child: SafeArea(
        child: Column(
          children: [
            // Flashcard carousel
            SizedBox(
              height: 310,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  OnboardingCard(
                    imagePath: 'lib/assets/images/household/House.png',
                    title: context.l10n.welcomeToHouseholds,
                    body: context.l10n.manageMoneyTogether,
                  ),
                  OnboardingCard(
                    imagePath: 'lib/assets/images/household/Money.png',
                    title: context.l10n.sharedBudgetsExpenses,
                    body: context.l10n.sharedBudgetsExpensesDesc,
                  ),
                  OnboardingCard(
                    imagePath: 'lib/assets/images/household/Balance.png',
                    title: context.l10n.smartExpenseSplitting,
                    body: context.l10n.smartExpenseSplittingDesc,
                  ),
                  OnboardingCard(
                    imagePath: 'lib/assets/images/household/Bell-Sync.png',
                    title: context.l10n.stayInSync,
                    body: context.l10n.stayInSyncDesc,
                  ),
                ],
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: PageIndicator(
                currentPage: _currentPage,
                totalPages: _totalPages,
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Create Household button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: shadcnui.PrimaryButton(
                      onPressed: _navigateToCreate,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            context.l10n.createHousehold,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primaryForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Join with Invite button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: shadcnui.OutlineButton(
                      onPressed: _navigateToJoin,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.link, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            context.l10n.joinWithInvite,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HouseholdCreatePage(),
      ),
    );
  }

  void _navigateToJoin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HouseholdJoinPage(),
      ),
    );
  }
}
