import 'package:moneko/features/households/domain/entities/household.dart';

String? resolveHouseholdPayerUserIdFromHint({
  required List<HouseholdMember> members,
  required String hint,
}) {
  final cleanedHint = _normalizePayerHint(hint);
  if (cleanedHint.isEmpty) return null;

  final hintLooksLikeEmail = cleanedHint.contains('@');

  for (final member in members) {
    final email = _normalizePayerHint(member.userEmail);
    if (hintLooksLikeEmail && email.isNotEmpty && email == cleanedHint) {
      return member.userId;
    }
  }

  for (final member in members) {
    final name = _normalizePayerHint(member.userName);
    if (name.isNotEmpty && name == cleanedHint) {
      return member.userId;
    }
  }

  for (final member in members) {
    final name = _normalizePayerHint(member.userName);
    if (name.isEmpty) continue;
    final first = name.split(' ').first;
    if (first.isNotEmpty && first == cleanedHint) {
      return member.userId;
    }
  }

  for (final member in members) {
    final name = _normalizePayerHint(member.userName);
    if (name.isNotEmpty && name.contains(cleanedHint)) {
      return member.userId;
    }
    final email = _normalizePayerHint(member.userEmail);
    if (email.isNotEmpty && email.contains(cleanedHint)) {
      return member.userId;
    }
  }

  return null;
}

String _normalizePayerHint(String? value) {
  if (value == null) return '';
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^[\s\-:]*paid\s+by\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9@._+\-\s]'), '')
      .trim();
}
