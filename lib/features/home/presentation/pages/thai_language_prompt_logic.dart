import 'package:flutter/widgets.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';

const thaiLanguagePromptCheckedPrefsKeyPrefix =
    'thai_language_prompt_checked_v1';

String thaiLanguagePromptCheckedPrefsKeyForUser(String userId) =>
    '$thaiLanguagePromptCheckedPrefsKeyPrefix:$userId';

enum ThaiLanguagePromptAction {
  waitForContact,
  skipForNow,
  markCheckedAndSkip,
  showPrompt,
}

class ThaiLanguagePromptDecision {
  const ThaiLanguagePromptDecision({required this.action});

  final ThaiLanguagePromptAction action;
}

ThaiLanguagePromptDecision evaluateThaiLanguagePrompt({
  required bool hasChecked,
  required UserContact? contact,
  required Locale currentLocale,
}) {
  if (hasChecked) {
    return const ThaiLanguagePromptDecision(
      action: ThaiLanguagePromptAction.markCheckedAndSkip,
    );
  }

  if (contact == null) {
    return const ThaiLanguagePromptDecision(
      action: ThaiLanguagePromptAction.waitForContact,
    );
  }

  final preferredTimezone = contact.preferredTimezone?.trim();
  final preferredCurrency = contact.preferredCurrency?.trim().toUpperCase();
  final isEligible =
      preferredTimezone == 'Asia/Bangkok' || preferredCurrency == 'THB';
  if (!isEligible) {
    return const ThaiLanguagePromptDecision(
      action: ThaiLanguagePromptAction.skipForNow,
    );
  }

  final isAlreadyThai = currentLocale.languageCode.toLowerCase() == 'th';
  if (isAlreadyThai) {
    return const ThaiLanguagePromptDecision(
      action: ThaiLanguagePromptAction.markCheckedAndSkip,
    );
  }

  return const ThaiLanguagePromptDecision(
    action: ThaiLanguagePromptAction.showPrompt,
  );
}
