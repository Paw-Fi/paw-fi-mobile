import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/presentation/utils/household_split_update_intent.dart';

void main() {
  test('ordinary edits preserve a historical payer and participant set', () {
    expect(
      shouldSendHouseholdSplitPayerMutation(
        isSharedSpace: true,
        hasExistingSplitGroup: true,
        staysInSameSharedHousehold: true,
        payerChangedByUser: false,
      ),
      isFalse,
    );
    expect(
      isExplicitHouseholdReSplitRequested(splitChangedByUser: false),
      isFalse,
    );
  });

  test('an explicit split edit is labeled as a re-split', () {
    expect(
      isExplicitHouseholdReSplitRequested(splitChangedByUser: true),
      isTrue,
    );
    expect(
      isExplicitHouseholdReSplitRequested(
        splitChangedByUser: false,
        payerChangedByUser: true,
      ),
      isTrue,
    );
  });

  test('new, moved, or explicitly changed payers are sent to the server', () {
    expect(
      shouldSendHouseholdSplitPayerMutation(
        isSharedSpace: true,
        hasExistingSplitGroup: false,
        staysInSameSharedHousehold: true,
        payerChangedByUser: false,
      ),
      isTrue,
    );
    expect(
      shouldSendHouseholdSplitPayerMutation(
        isSharedSpace: true,
        hasExistingSplitGroup: true,
        staysInSameSharedHousehold: false,
        payerChangedByUser: false,
      ),
      isTrue,
    );
    expect(
      shouldSendHouseholdSplitPayerMutation(
        isSharedSpace: true,
        hasExistingSplitGroup: true,
        staysInSameSharedHousehold: true,
        payerChangedByUser: true,
      ),
      isTrue,
    );
  });

  test('member loading preserves a departed payer on an existing split', () {
    expect(
      resolveHouseholdPayerAfterMemberLoad(
        currentPayerUserId: 'departed-user',
        currentMemberUserIds: const ['current-user', 'new-member'],
        isNewExpense: false,
        hasExistingSplitGroup: true,
      ),
      'departed-user',
    );
  });

  test('new splits default an unavailable payer to a current member', () {
    expect(
      resolveHouseholdPayerAfterMemberLoad(
        currentPayerUserId: 'departed-user',
        currentMemberUserIds: const ['current-user', 'new-member'],
        isNewExpense: true,
        hasExistingSplitGroup: false,
      ),
      'current-user',
    );
  });
}
