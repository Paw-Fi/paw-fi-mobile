import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// A generic error page that displays error information and provides
/// a way to navigate back to the home page.
class ErrorPage extends ConsumerWidget {
  /// The error object to display.
  final Exception? error;

  /// Additional context to show above the raw error text.
  final String? details;

  /// Stack trace for debugging (optional).
  final StackTrace? stackTrace;

  /// Creates an ErrorPage.
  const ErrorPage(
    this.error, {
    this.details,
    this.stackTrace,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initNotifier = ref.read(appInitializationV2Provider.notifier);
    final fallbackError = initNotifier.lastInitException;
    final displayError = error ?? fallbackError;
    final stack = stackTrace ?? initNotifier.lastErrorStackTrace;
    final message = details ??
        initNotifier.lastErrorMessage ??
        displayError?.toString() ??
        context.l10n.unknownError;
    final hasInitFailure = initNotifier.lastInitException != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.errorTitle),
        backgroundColor: Colors.red.shade800,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.anErrorOccurred,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We hit a critical issue while loading the app.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.details,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          message,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.start,
                        ),
                        if (stack != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.technicalInfo,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            stack.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.red.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (hasInitFailure)
                    ElevatedButton(
                      onPressed: () {
                        initNotifier.reset();
                        context.go('/splash');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        context.l10n.retryInitialization,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  if (hasInitFailure) const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      if (hasInitFailure) {
                        initNotifier.reset();
                        context.go('/splash');
                      } else {
                        context.go('/');
                      }
                    },
                    child: Text(
                      context.l10n.goToHome,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
