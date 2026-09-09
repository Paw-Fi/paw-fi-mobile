import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/presentation/state/pocket_lineage_mutations.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

void main() {
  const metadata = PocketLineageMetadata(
    lineageId: 'lineage-food',
    revision: 4,
    fundingPolicy: 'decide_each_cycle',
  );

  group('pocket lineage mutation payloads', () {
    test('serializes a funding change with the loaded revision', () {
      final payload = buildPocketLineageFundingPayload(
        userId: 'user-1',
        scope: PocketsScopeType.personal,
        householdId: null,
        metadata: metadata,
        fundingPolicy: 'refill_to',
        fundingTargetCents: 50000,
      );

      expect(payload['p_expected_revision'], 4);
      expect(payload['p_funding_policy'], 'refill_to');
      expect(payload['p_funding_target_cents'], 50000);
    });

    test('makes category assignment follow a queued funding revision', () {
      final payload = buildPocketLineageCategoriesPayload(
        userId: 'user-1',
        scope: PocketsScopeType.personal,
        householdId: null,
        metadata: metadata,
        effectiveMonth: '2026-09-01',
        categories: const [' Groceries ', 'dining', 'groceries'],
        followsFundingChange: true,
      );

      expect(payload['p_expected_revision'], 5);
      expect(payload['p_categories'], ['groceries', 'dining']);
    });

    test('requires a target for a balance transfer retirement', () {
      expect(
        () => buildPocketLineageRetirementPayload(
          userId: 'user-1',
          scope: PocketsScopeType.personal,
          householdId: null,
          metadata: metadata,
          effectiveMonth: '2026-09-01',
          disposition: PocketRetirementDisposition.transferPositive,
          targetLineageId: null,
        ),
        throwsArgumentError,
      );
    });

    test('does not attach a target when releasing a positive balance', () {
      final payload = buildPocketLineageRetirementPayload(
        userId: 'user-1',
        scope: PocketsScopeType.personal,
        householdId: null,
        metadata: metadata,
        effectiveMonth: '2026-09-01',
        disposition: PocketRetirementDisposition.releasePositive,
        targetLineageId: null,
      );

      expect(payload['p_disposition'], 'release_positive');
      expect(payload['p_target_lineage_id'], isNull);
    });

    test('creates one atomic new-pocket lifecycle snapshot', () {
      final payload = buildPocketLineageLifecyclePayload(
        userId: 'user-1',
        scope: PocketsScopeType.personal,
        householdId: null,
        lineageId: null,
        expectedRevision: null,
        budgetMonth: '2026-09-01',
        currency: 'usd',
        operationId: '00000000-0000-4000-8000-000000000001',
        name: ' Food ',
        icon: 'restaurant',
        color: '#123456',
        logoUrl: 'https://example.test/food.png',
        rolloverEnabled: true,
        rolloverNegative: false,
        rolloverCapCents: null,
        fundingPolicy: 'add_every_cycle',
        fundingTargetCents: 60000,
        categories: const [' Groceries ', 'dining', 'groceries'],
        currentAmountCents: 60000,
      );

      expect(payload['p_lineage_id'], isNull);
      expect(payload['p_expected_revision'], isNull);
      expect(payload['p_currency'], 'USD');
      expect(payload['p_categories'], ['groceries', 'dining']);
      expect(payload['p_logo_url'], 'https://example.test/food.png');
      expect(payload['p_rollover_cap_cents'], isNull);
      expect(payload['p_current_amount_cents'], 60000);
    });

    test('updates metadata, categories, and allocation at one revision', () {
      final payload = buildPocketLineageLifecyclePayload(
        userId: 'user-1',
        scope: PocketsScopeType.household,
        householdId: 'household-1',
        lineageId: metadata.lineageId,
        expectedRevision: metadata.revision,
        budgetMonth: '2026-09-01',
        currency: 'USD',
        operationId: '00000000-0000-4000-8000-000000000002',
        name: 'Food',
        icon: 'restaurant',
        color: '#123456',
        logoUrl: null,
        rolloverEnabled: false,
        rolloverNegative: false,
        rolloverCapCents: null,
        fundingPolicy: 'decide_each_cycle',
        fundingTargetCents: null,
        categories: const ['groceries'],
        currentAmountCents: 45000,
      );

      expect(payload['p_lineage_id'], metadata.lineageId);
      expect(payload['p_expected_revision'], metadata.revision);
      expect(payload['p_categories'], ['groceries']);
      expect(payload['p_current_amount_cents'], 45000);
      expect(payload['p_rollover_cap_cents'], isNull);
    });
  });
}
