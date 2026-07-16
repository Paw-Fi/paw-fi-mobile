import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/constants/links.dart';

void main() {
  test('Reddit community link points to the Moneko subreddit', () {
    final uri = Uri.parse(Links.redditCommunity);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.reddit.com');
    expect(uri.path, '/r/monekobudget/');
  });

  test('changelog link points to the Moneko changelog', () {
    final uri = Uri.parse(Links.changelog);

    expect(uri.scheme, 'https');
    expect(uri.host, 'moneko.io');
    expect(uri.path, '/changelog');
  });
}
