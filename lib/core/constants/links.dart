/// Centralized external link constants for the Moneko app
///
/// Use these for URLs that are opened in an external browser or app
/// (e.g. Discord support, marketing pages, documentation).
abstract class Links {
  Links._();

  /// Discord support / community server
  static const String discordSupport = 'https://discord.gg/M2Dgujvtze';

  /// Moneko community subreddit
  static const String redditCommunity =
      'https://www.reddit.com/r/monekobudget/';

  /// Product updates and release notes
  static const String changelog =
      'https://moneko.io/changelog?source=mobile-changelog';

  /// Support email address
  static const String supportEmail = 'mailto:hello@moneko.io';

  /// Web forgot password flow
  static const String forgotPassword = 'https://moneko.io/forgot-password';
}
