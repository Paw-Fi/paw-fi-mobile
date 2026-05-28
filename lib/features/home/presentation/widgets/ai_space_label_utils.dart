import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

class AiInputSpaceOption {
  const AiInputSpaceOption({
    required this.accountType,
    required this.label,
    this.householdId,
    this.isPortfolio = false,
  });

  final ActiveWalletType accountType;
  final String label;
  final String? householdId;
  final bool isPortfolio;

  @override
  bool operator ==(Object other) {
    return other is AiInputSpaceOption &&
        other.accountType == accountType &&
        other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(accountType, householdId);
}

IconData resolveAiInputSpaceOptionIcon(AiInputSpaceOption option) {
  if (option.accountType == ActiveWalletType.personal) {
    return Icons.account_circle;
  }
  return option.isPortfolio ? Icons.person : Icons.group;
}

List<AdaptivePopupMenuItem> buildAiInputSpaceMenuItems(
  List<AiInputSpaceOption> options, {
  bool reverseForBottomAnchor = false,
}) {
  final source = reverseForBottomAnchor
      ? options.reversed.toList(growable: false)
      : options;
  return source
      .map(
        (option) => AdaptivePopupMenuItem(
          label: option.label,
          icon: resolveAiInputSpaceOptionIcon(option),
          value: option,
        ),
      )
      .toList(growable: false);
}

String _emailLocalPart(String email) {
  final trimmed = email.trim();
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return trimmed;
  return trimmed.substring(0, atIndex);
}

String resolveAiPersonalSpaceLabel(AppUser user) {
  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  return _emailLocalPart(user.email);
}

String formatAiHouseholdSpaceOptionLabel(
  BuildContext context,
  Household household,
) {
  return household.isPortfolio
      ? '${household.name} · ${context.l10n.privateSpace}'
      : '${household.name} · ${context.l10n.sharedSpace}';
}

List<AiInputSpaceOption> buildAiInputSpaceOptions(
  BuildContext context, {
  required List<Household> households,
  required String personalLabel,
}) {
  return <AiInputSpaceOption>[
    AiInputSpaceOption(
      accountType: ActiveWalletType.personal,
      label: personalLabel,
    ),
    for (final household in households)
      AiInputSpaceOption(
        accountType: household.isPortfolio
            ? ActiveWalletType.portfolio
            : ActiveWalletType.household,
        householdId: household.id,
        isPortfolio: household.isPortfolio,
        label: formatAiHouseholdSpaceOptionLabel(context, household),
      ),
  ];
}

String resolveAiSelectedSpaceLabel(
  BuildContext context, {
  required ActiveWalletType accountType,
  required String? selectedHouseholdId,
  required List<Household> households,
  required String personalLabel,
}) {
  switch (accountType) {
    case ActiveWalletType.personal:
      return personalLabel;
    case ActiveWalletType.portfolio:
      for (final household in households) {
        if (household.id == selectedHouseholdId) return household.name;
      }
      return context.l10n.privateSpace;
    case ActiveWalletType.household:
      for (final household in households) {
        if (household.id == selectedHouseholdId) return household.name;
      }
      return context.l10n.tapToSet;
  }
}
