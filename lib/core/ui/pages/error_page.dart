import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

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
    final auth = ref.read(authProvider);
    final fallbackError = initNotifier.lastInitException;
    final displayError = error ?? fallbackError;
    final stack = stackTrace ?? initNotifier.lastErrorStackTrace;
    final message = details ??
        initNotifier.lastErrorMessage ??
        displayError?.toString() ??
        context.l10n.unknownError;
    final hasInitFailure = initNotifier.lastInitException != null;
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            TargetPlatform.macOS => 'macos',
            TargetPlatform.windows => 'windows',
            TargetPlatform.linux => 'linux',
            TargetPlatform.fuchsia => 'fuchsia',
          };
    final userId = auth.isEmpty ? null : auth.uid;
    final tzOffset = DateTime.now().timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes =
        (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final timezone =
        '${DateTime.now().timeZoneName} ($tzSign$tzHours:$tzMinutes)';
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final brightness = Theme.of(context).brightness.name;
    final media = MediaQuery.of(context);
    final screen =
        '${media.size.width.toStringAsFixed(0)}x${media.size.height.toStringAsFixed(0)}@${media.devicePixelRatio.toStringAsFixed(2)}';
    final stackPreview = stack?.toString().split('\n').take(6).join('\n');
    final supportId =
        '${now.toIso8601String()}|$platform|${userId ?? 'no_user'}'
            .hashCode
            .toUnsigned(32)
            .toRadixString(16)
            .padLeft(8, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.errorTitle),
        backgroundColor: colorScheme.destructive,
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
                  Icon(
                    Icons.error_outline,
                    color: colorScheme.errorAccent,
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
                      color: colorScheme.errorSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.errorBorder),
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
                        const SizedBox(height: 16),
                        Text(
                          'Support snapshot (send screenshot)',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: colorScheme.errorAccent),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            final pkg = snapshot.data;
                            final appVersion = pkg == null
                                ? 'unknown'
                                : '${pkg.version}+${pkg.buildNumber}';

                            final debug = <String, dynamic>{
                              'support_id': supportId,
                              'time_local': now.toIso8601String(),
                              'timezone': timezone,
                              'platform': platform,
                              'mode': kReleaseMode
                                  ? 'release'
                                  : (kProfileMode ? 'profile' : 'debug'),
                              'brightness': brightness,
                              'locale': locale,
                              'screen': screen,
                              'app_version': appVersion,
                              'route':
                                  GoRouterState.of(context).matchedLocation,
                              'user_id': userId,
                              'error_type':
                                  displayError?.runtimeType.toString(),
                              'error': displayError?.toString(),
                              'details_param': details,
                              'init_has_failure': hasInitFailure,
                              'init_message': message,
                              'stack_present': stack != null,
                              'stack_preview': stackPreview,
                              'init_debug': initNotifier.getDebugSnapshot(),
                            };

                            return SelectableText(
                              debug.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join('\n'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colorScheme.errorAccent),
                            );
                          },
                        ),
                        if (stack != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.technicalInfo,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: colorScheme.errorAccent),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            stack.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.errorAccent),
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
                        backgroundColor: colorScheme.destructive,
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
