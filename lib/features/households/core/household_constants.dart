/// Constants for household feature
class HouseholdConstants {
  /// Default invitation expiration in days
  static const int defaultInviteExpirationDays = 7;

  /// Available invitation expiration options (in days). 0 = Unlimited
  static const List<int> inviteExpirationOptions = [1, 3, 7, 14, 30, 0];

  /// Minimum household name length
  static const int minNameLength = 2;

  /// Maximum household name length
  static const int maxNameLength = 50;

  /// Token validation regex pattern (UUID-like format)
  /// Matches UUIDs and base64-encoded tokens (32+ chars, alphanumeric + hyphens)
  static final RegExp tokenPattern = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$|^[A-Za-z0-9_-]{32,}$',
  );

  /// URL patterns for invitation links
  static final List<RegExp> inviteUrlPatterns = [
    RegExp(r'moneko\.app/invites/([a-zA-Z0-9_-]+)'),
    RegExp(r'localhost:\d+/invites/([a-zA-Z0-9_-]+)'),
    RegExp(r'/invites/([a-zA-Z0-9_-]+)'),
  ];

  /// Debounce duration for validation calls (milliseconds)
  static const int validationDebounceMs = 500;

  /// Retry configuration
  static const int maxRetryAttempts = 3;
  static const int retryDelayMs = 1000;

  /// Accessibility labels for create page
  static const String coverImageSemanticLabel = 'Household cover image';
  static const String editCoverButtonLabel = 'Edit household cover image';
  static const String closeButtonLabel = 'Close';
  static const String backButtonLabel = 'Go back';
  static const String cancelButtonLabel = 'Cancel';
  static const String continueButtonLabel = 'Continue to validate invitation';
  static const String tryAgainButtonLabel = 'Try joining household again';

  /// Accessibility labels for join page
  static const String joinPageHeaderLabel = 'Join household page';
  static const String joinHeroLabel = 'Join a household with invitation link';
  static const String joinInstructionsLabel =
      'Paste the invitation link you received from a household member';
  static const String inviteLinkInputLabel = 'Enter invitation link';
  static const String pasteButtonLabel = 'Paste invitation link from clipboard';
  static const String clearInputButtonLabel = 'Clear invitation link input';
  static const String validatingButtonLabel = 'Validating invitation link';
  static const String benefitsCardLabel =
      'Benefits of joining household: view shared budgets, track financial health, collaborate on decisions';
  static const String joiningHouseholdLabel = 'Joining household, please wait';
  static const String joinSuccessLabel = 'Successfully joined household';
  static const String goToHouseholdButtonLabel = 'Go to household overview';
}
