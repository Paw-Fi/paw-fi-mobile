import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/pages/thai_language_prompt_logic.dart';

void main() {
  final bangkokContact = UserContact(
    id: 'contact-1',
    userId: 'user-1',
    verified: true,
    preferredTimezone: 'Asia/Bangkok',
  );

  test('waits until contact data exists', () {
    final decision = evaluateThaiLanguagePrompt(
      hasChecked: false,
      contact: null,
      currentLocale: const Locale('en'),
    );

    expect(decision.action, ThaiLanguagePromptAction.waitForContact);
  });

  test('shows prompt for Bangkok users when locale is not Thai', () {
    final decision = evaluateThaiLanguagePrompt(
      hasChecked: false,
      contact: bangkokContact,
      currentLocale: const Locale('en'),
    );

    expect(decision.action, ThaiLanguagePromptAction.showPrompt);
  });

  test('shows prompt for Thai baht users even without Bangkok timezone', () {
    final decision = evaluateThaiLanguagePrompt(
      hasChecked: false,
      contact: UserContact(
        id: 'contact-3',
        userId: 'user-3',
        verified: true,
        preferredCurrency: 'THB',
        preferredTimezone: 'Asia/Tokyo',
      ),
      currentLocale: const Locale('en'),
    );

    expect(decision.action, ThaiLanguagePromptAction.showPrompt);
  });

  test('marks checked and skips for eligible users already using Thai', () {
    final decision = evaluateThaiLanguagePrompt(
      hasChecked: false,
      contact: bangkokContact,
      currentLocale: const Locale('th'),
    );

    expect(decision.action, ThaiLanguagePromptAction.markCheckedAndSkip);
  });

  test('skips for now for users outside Thai currency and timezone signals',
      () {
    final contact = UserContact(
      id: 'contact-2',
      userId: 'user-2',
      verified: true,
      preferredCurrency: 'JPY',
      preferredTimezone: 'Asia/Tokyo',
    );

    final decision = evaluateThaiLanguagePrompt(
      hasChecked: false,
      contact: contact,
      currentLocale: const Locale('en'),
    );

    expect(decision.action, ThaiLanguagePromptAction.skipForNow);
  });

  test('never prompts again after the check was already completed', () {
    final decision = evaluateThaiLanguagePrompt(
      hasChecked: true,
      contact: bangkokContact,
      currentLocale: const Locale('en'),
    );

    expect(decision.action, ThaiLanguagePromptAction.markCheckedAndSkip);
  });

  test('scopes checked key per user', () {
    expect(
      thaiLanguagePromptCheckedPrefsKeyForUser('user-1'),
      'thai_language_prompt_checked_v1:user-1',
    );
  });
}
