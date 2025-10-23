import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../widgets/onboarding_card.dart';
import 'household_create_page.dart';
import 'household_join_page.dart';

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
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.background,
      child: SafeArea(
        child: Column(
          children: [
            // Flashcard carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: const [
                  OnboardingCard(
                    emoji: '🏠',
                    title: 'Welcome to Households',
                    body: 'Manage money together with your partner, family, or roommates in one shared space.',
                  ),
                  OnboardingCard(
                    emoji: '💰',
                    title: 'Shared Budgets & Expenses',
                    body: 'Set budgets, track spending, and see where your household money goes in real-time.',
                  ),
                  OnboardingCard(
                    emoji: '⚖️',
                    title: 'Smart Expense Splitting',
                    body: 'Automatically calculate who owes what with flexible split options: equal, percentage, or custom amounts.',
                  ),
                  OnboardingCard(
                    emoji: '🔔',
                    title: 'Stay in Sync',
                    body: 'Get notified when expenses are added, budgets are reached, or splits need settling.',
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
                            'Create Household',
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
                            'Join with Invite',
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
