import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Tracks the currently selected tab index in the MainShell bottom
/// navigation. 0 = Overview, 1 = Recurring, 2 = Pockets, 3 = Accounts, 4 = Insights.
final mainShellTabIndexProvider = StateProvider<int>((ref) => 0);
