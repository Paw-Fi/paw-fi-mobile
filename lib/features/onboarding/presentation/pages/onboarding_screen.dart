import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:moneko/features/onboarding/presentation/widgets/chat_bubble.dart';
import 'package:moneko/features/onboarding/presentation/widgets/questionnaire_modal.dart';
import 'package:moneko/features/onboarding/presentation/widgets/goal_presentation_modal.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageController = useTextEditingController();
    final scrollController = useScrollController();
    final messages = ref.watch(onboardingChatProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final auth = ref.watch(authProvider);
    final currentGoal = ref.watch(currentGoalProvider);

    final showQuestionnaire = useState(false);
    final showGoalPresentation = useState(false);

    // Initialize chat on first load
    useEffect(() {
      Future.microtask(() {
        if (messages.isEmpty) {
          ref.read(onboardingChatProvider.notifier).initializeChat();
        }
      });
      return null;
    }, []);

    // Auto-scroll to bottom when new messages arrive
    useEffect(() {
      if (messages.isNotEmpty && scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
      return null;
    }, [messages.length]);

    Future<void> handleSendMessage() async {
      final message = messageController.text.trim();
      if (message.isEmpty || isLoading) return;

      messageController.clear();
      ref.read(chatLoadingProvider.notifier).setLoading(true);

      try {
        await ref.read(onboardingChatProvider.notifier).sendMessage(
              message: message,
              isFirstMessage: false,
              withWelcomeAndResponse: false,
            );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        ref.read(chatLoadingProvider.notifier).setLoading(false);
      }
    }

    void handleStartQuestionnaire(String mode) {
      showQuestionnaire.value = true;
    }

    void handleQuestionnaireComplete(Map<String, dynamic> data) {
      showQuestionnaire.value = false;
      // Goal creation will be handled in the modal
      showGoalPresentation.value = true;
    }

    void handleGoalPresentationComplete() {
      showGoalPresentation.value = false;

      // If user is authenticated, go to dashboard
      // Otherwise, prompt for registration
      if (!auth.isEmpty) {
        context.go('/dashboard');
      } else {
        // Show registration prompt
        _showRegistrationPrompt(context);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Goal Setup'),
        centerTitle: true,
        actions: [
          if (!auth.isEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.go('/dashboard'),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Chat messages
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Loading...'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ChatBubble(
                            message: message.content,
                            isUser: message.isUser,
                            timestamp: message.timestamp,
                          );
                        },
                      ),
              ),

              // Action buttons (show after AI intro)
              if (messages.length >= 2 && !isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => handleStartQuestionnaire('faster'),
                          child: const Text('Quick Setup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: shadcnui.PrimaryButton(
                          onPressed: () =>
                              handleStartQuestionnaire('customized'),
                          child: const Text('Detailed Setup'),
                        ),
                      ),
                    ],
                  ),
                ),

              // Message input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: shadcnui.Theme.of(context).colorScheme.background,
                  border: Border(
                    top: BorderSide(
                      color: shadcnui.Theme.of(context).colorScheme.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: isLoading
                              ? 'AI is thinking...'
                              : 'Ask me anything about your financial goals...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => handleSendMessage(),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: isLoading ? null : handleSendMessage,
                      icon: Icon(
                        Icons.send,
                        color: isLoading
                            ? shadcnui.Theme.of(context).colorScheme.mutedForeground
                            : shadcnui.Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Questionnaire modal
          if (showQuestionnaire.value)
            QuestionnaireModal(
              onComplete: handleQuestionnaireComplete,
              onClose: () => showQuestionnaire.value = false,
            ),

          // Goal presentation modal
          if (showGoalPresentation.value && currentGoal != null)
            GoalPresentationModal(
              goal: currentGoal,
              onComplete: handleGoalPresentationComplete,
              onClose: () => showGoalPresentation.value = false,
            ),
        ],
      ),
    );
  }

  void _showRegistrationPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Your Progress'),
        content: const Text(
          'Create an account to save your financial goal and track your progress.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/dashboard');
            },
            child: const Text('Continue as Guest'),
          ),
          shadcnui.PrimaryButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/register');
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}
