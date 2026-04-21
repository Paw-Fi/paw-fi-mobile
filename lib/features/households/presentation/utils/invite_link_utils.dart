import '../../core/household_constants.dart';

const _inviteLinkBase = 'https://moneko.io';

String buildInviteLink(String tokenOrUrl) {
  final trimmed = tokenOrUrl.trim();
  if (trimmed.isEmpty) return trimmed;

  final extracted = _extractInviteToken(trimmed);
  if (extracted != null) {
    return '$_inviteLinkBase/invites/$extracted';
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  return '$_inviteLinkBase/invites/$trimmed';
}

String? _extractInviteToken(String value) {
  final candidates = <String>[value];

  try {
    final decoded = Uri.decodeComponent(value);
    if (decoded != value) {
      candidates.add(decoded);
    }
  } catch (_) {}

  for (final candidate in candidates) {
    final matches = RegExp(r'(?:^|/)invites/([A-Za-z0-9_-]+)(?=$|[/?#])')
        .allMatches(candidate);
    if (matches.isNotEmpty) {
      final token = matches.last.group(1);
      if (token != null && HouseholdConstants.tokenPattern.hasMatch(token)) {
        return token;
      }
    }

    if (HouseholdConstants.tokenPattern.hasMatch(candidate)) {
      return candidate;
    }
  }

  return null;
}
