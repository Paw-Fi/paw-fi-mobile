import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/income/domain/models/income_entry.dart';

void main() {
  group('IncomeEntry - Model Creation', () {
    test('creates income entry with all required fields', () {
      final now = DateTime(2024, 1, 1);
      final entry = IncomeEntry(
        id: 'inc_1',
        date: now,
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: now,
        privacyRedacted: false,
      );

      expect(entry.id, 'inc_1');
      expect(entry.date, now);
      expect(entry.category, 'Salary');
      expect(entry.amount, 5000.0);
      expect(entry.currency, 'USD');
      expect(entry.ownerType, 'me');
      expect(entry.privacyScope, 'full');
      expect(entry.isAcknowledged, false);
      expect(entry.acknowledgedCount, 0);
      expect(entry.isRecurring, false);
      expect(entry.attachments, []);
      expect(entry.privacyRedacted, false);
    });

    test('creates income entry with all optional fields', () {
      final now = DateTime(2024, 1, 1);
      final recurrenceRule = RecurrenceRule(
        frequency: 'monthly',
        anchorDate: now,
        endDate: DateTime(2024, 12, 31),
        interval: 1,
      );
      final attachments = [
        Attachment(
          url: 'https://example.com/doc.pdf',
          type: 'pdf',
          name: 'Invoice.pdf',
          size: 1024,
        ),
      ];

      final entry = IncomeEntry(
        id: 'inc_1',
        date: now,
        category: 'Freelance',
        description: 'Project payment',
        source: 'Client A',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'household',
        privacyScope: 'balances_only',
        householdId: 'hh_1',
        isAcknowledged: true,
        acknowledgedCount: 3,
        normalizedAmount: 5500.0,
        baseCurrency: 'EUR',
        fxRate: 1.1,
        isRecurring: true,
        recurrenceRule: recurrenceRule,
        parentRecurringId: 'rec_1',
        attachments: attachments,
        createdAt: now,
        updatedAt: now,
        privacyRedacted: true,
      );

      expect(entry.description, 'Project payment');
      expect(entry.source, 'Client A');
      expect(entry.ownerType, 'household');
      expect(entry.privacyScope, 'balances_only');
      expect(entry.householdId, 'hh_1');
      expect(entry.isAcknowledged, true);
      expect(entry.acknowledgedCount, 3);
      expect(entry.normalizedAmount, 5500.0);
      expect(entry.baseCurrency, 'EUR');
      expect(entry.fxRate, 1.1);
      expect(entry.isRecurring, true);
      expect(entry.recurrenceRule, recurrenceRule);
      expect(entry.parentRecurringId, 'rec_1');
      expect(entry.attachments.length, 1);
      expect(entry.privacyRedacted, true);
    });
  });

  group('IncomeEntry - JSON Serialization', () {
    test('fromJson parses income entry correctly', () {
      final json = {
        'id': 'inc_1',
        'date': '2024-01-01T00:00:00.000Z',
        'category': 'Salary',
        'description': 'Monthly salary',
        'source': 'Company',
        'amountMajor': 5000.0,
        'currency': 'USD',
        'ownerType': 'me',
        'privacyScope': 'full',
        'householdId': 'hh_1',
        'isAcknowledged': true,
        'acknowledgedCount': 2,
        'normalizedAmountMajor': 5500.0,
        'baseCurrency': 'EUR',
        'fxRate': 1.1,
        'isRecurring': true,
        'recurrenceRule': {
          'frequency': 'monthly',
          'anchor_date': '2024-01-01T00:00:00.000Z',
          'end_date': '2024-12-31T00:00:00.000Z',
          'interval': 1,
        },
        'parentRecurringId': 'rec_1',
        'attachments': [
          {
            'url': 'https://example.com/doc.pdf',
            'type': 'pdf',
            'name': 'Invoice.pdf',
            'size': 1024,
          },
        ],
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
        'privacyRedacted': true,
      };

      final entry = IncomeEntry.fromJson(json);

      expect(entry.id, 'inc_1');
      expect(entry.date.year, 2024);
      expect(entry.date.month, 1);
      expect(entry.date.day, 1);
      expect(entry.category, 'Salary');
      expect(entry.description, 'Monthly salary');
      expect(entry.source, 'Company');
      expect(entry.amount, 5000.0);
      expect(entry.currency, 'USD');
      expect(entry.ownerType, 'me');
      expect(entry.privacyScope, 'full');
      expect(entry.householdId, 'hh_1');
      expect(entry.isAcknowledged, true);
      expect(entry.acknowledgedCount, 2);
      expect(entry.normalizedAmount, 5500.0);
      expect(entry.baseCurrency, 'EUR');
      expect(entry.fxRate, 1.1);
      expect(entry.isRecurring, true);
      expect(entry.recurrenceRule, isNotNull);
      expect(entry.parentRecurringId, 'rec_1');
      expect(entry.attachments.length, 1);
      expect(entry.createdAt, DateTime.utc(2024, 1, 1));
      expect(entry.updatedAt, DateTime.utc(2024, 1, 2));
      expect(entry.privacyRedacted, true);
    });

    test('fromJson handles default values', () {
      final json = {
        'id': 'inc_1',
        'date': '2024-01-01T00:00:00.000Z',
        'category': 'Salary',
        'amountMajor': 5000.0,
        'currency': 'USD',
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final entry = IncomeEntry.fromJson(json);

      expect(entry.ownerType, 'me');
      expect(entry.privacyScope, 'full');
      expect(entry.isAcknowledged, false);
      expect(entry.acknowledgedCount, 0);
      expect(entry.isRecurring, false);
      expect(entry.attachments, []);
      expect(entry.privacyRedacted, false);
    });

    test('fromJson handles null recurrence rule', () {
      final json = {
        'id': 'inc_1',
        'date': '2024-01-01T00:00:00.000Z',
        'category': 'Salary',
        'amountMajor': 5000.0,
        'currency': 'USD',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'recurrenceRule': null,
      };

      final entry = IncomeEntry.fromJson(json);

      expect(entry.recurrenceRule, null);
    });

    test('fromJson handles empty attachments', () {
      final json = {
        'id': 'inc_1',
        'date': '2024-01-01T00:00:00.000Z',
        'category': 'Salary',
        'amountMajor': 5000.0,
        'currency': 'USD',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'attachments': [],
      };

      final entry = IncomeEntry.fromJson(json);

      expect(entry.attachments, []);
    });

    test('toJson serializes income entry correctly', () {
      final now = DateTime(2024, 1, 1);
      final recurrenceRule = RecurrenceRule(
        frequency: 'monthly',
        anchorDate: now,
        interval: 1,
      );
      final attachments = [
        Attachment(
          url: 'https://example.com/doc.pdf',
          type: 'pdf',
          name: 'Invoice.pdf',
          size: 1024,
        ),
      ];

      final entry = IncomeEntry(
        id: 'inc_1',
        date: now,
        category: 'Salary',
        description: 'Monthly salary',
        source: 'Company',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        householdId: 'hh_1',
        isAcknowledged: true,
        acknowledgedCount: 2,
        normalizedAmount: 5500.0,
        baseCurrency: 'EUR',
        fxRate: 1.1,
        isRecurring: true,
        recurrenceRule: recurrenceRule,
        parentRecurringId: 'rec_1',
        attachments: attachments,
        createdAt: now,
        updatedAt: now,
        privacyRedacted: true,
      );

      final json = entry.toJson();

      expect(json['id'], 'inc_1');
      expect(json['date'], '2024-01-01');
      expect(json['category'], 'Salary');
      expect(json['description'], 'Monthly salary');
      expect(json['source'], 'Company');
      expect(json['amountMajor'], 5000.0);
      expect(json['currency'], 'USD');
      expect(json['ownerType'], 'me');
      expect(json['privacyScope'], 'full');
      expect(json['householdId'], 'hh_1');
      expect(json['isAcknowledged'], true);
      expect(json['acknowledgedCount'], 2);
      expect(json['normalizedAmountMajor'], 5500.0);
      expect(json['baseCurrency'], 'EUR');
      expect(json['fxRate'], 1.1);
      expect(json['isRecurring'], true);
      expect(json['recurrenceRule'], isNotNull);
      expect(json['parentRecurringId'], 'rec_1');
      expect(json['attachments'], isA<List>());
      expect(json['createdAt'], '2024-01-01T00:00:00.000');
      expect(json['updatedAt'], '2024-01-01T00:00:00.000');
      expect(json['privacyRedacted'], true);
    });
  });

  group('IncomeEntry - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      final now = DateTime(2024, 1, 1);
      final original = IncomeEntry(
        id: 'inc_1',
        date: now,
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: now,
        privacyRedacted: false,
      );

      final updated = original.copyWith(
        amount: 6000.0,
        isAcknowledged: true,
        acknowledgedCount: 1,
      );

      expect(updated.id, 'inc_1');
      expect(updated.amount, 6000.0);
      expect(updated.isAcknowledged, true);
      expect(updated.acknowledgedCount, 1);
      expect(updated.category, 'Salary');
      expect(updated.currency, 'USD');
    });

    test('copyWith without parameters returns identical values', () {
      final now = DateTime(2024, 1, 1);
      final original = IncomeEntry(
        id: 'inc_1',
        date: now,
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: now,
        privacyRedacted: false,
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.amount, original.amount);
      expect(copy.category, original.category);
    });
  });

  group('IncomeEntry - Privacy Scopes', () {
    test('handles private privacy scope', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'private',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: true,
      );

      expect(entry.privacyScope, 'private');
      expect(entry.privacyRedacted, true);
    });

    test('handles balances_only privacy scope', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'balances_only',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.privacyScope, 'balances_only');
    });

    test('handles full privacy scope', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.privacyScope, 'full');
      expect(entry.privacyRedacted, false);
    });
  });

  group('IncomeEntry - Owner Types', () {
    test('handles me owner type', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.ownerType, 'me');
    });

    test('handles partner owner type', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'partner',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.ownerType, 'partner');
    });

    test('handles household owner type', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'household',
        privacyScope: 'full',
        householdId: 'hh_1',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.ownerType, 'household');
      expect(entry.householdId, 'hh_1');
    });
  });

  group('RecurrenceRule - Model', () {
    test('creates recurrence rule correctly', () {
      final now = DateTime(2024, 1, 1);
      final rule = RecurrenceRule(
        frequency: 'monthly',
        anchorDate: now,
        endDate: DateTime(2024, 12, 31),
        interval: 1,
      );

      expect(rule.frequency, 'monthly');
      expect(rule.anchorDate, now);
      expect(rule.endDate, DateTime(2024, 12, 31));
      expect(rule.interval, 1);
    });

    test('fromJson parses recurrence rule correctly', () {
      final json = {
        'frequency': 'weekly',
        'anchor_date': '2024-01-01T00:00:00.000Z',
        'end_date': '2024-12-31T00:00:00.000Z',
        'interval': 2,
      };

      final rule = RecurrenceRule.fromJson(json);

      expect(rule.frequency, 'weekly');
      expect(rule.anchorDate.year, 2024);
      expect(rule.anchorDate.month, 1);
      expect(rule.anchorDate.day, 1);
      expect(rule.endDate, isNotNull);
      expect(rule.endDate!.year, 2024);
      expect(rule.endDate!.month, 12);
      expect(rule.endDate!.day, 31);
      expect(rule.interval, 2);
    });

    test('fromJson handles null end date', () {
      final json = {
        'frequency': 'monthly',
        'anchor_date': '2024-01-01T00:00:00.000Z',
        'interval': 1,
      };

      final rule = RecurrenceRule.fromJson(json);

      expect(rule.endDate, null);
    });

    test('toJson serializes recurrence rule correctly', () {
      final rule = RecurrenceRule(
        frequency: 'yearly',
        anchorDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        interval: 1,
      );

      final json = rule.toJson();

      expect(json['frequency'], 'yearly');
      expect(json['anchor_date'], '2024-01-01');
      expect(json['end_date'], '2024-12-31');
      expect(json['interval'], 1);
    });
  });

  group('Attachment - Model', () {
    test('creates attachment correctly', () {
      final attachment = Attachment(
        url: 'https://example.com/doc.pdf',
        type: 'pdf',
        name: 'Invoice.pdf',
        size: 2048,
      );

      expect(attachment.url, 'https://example.com/doc.pdf');
      expect(attachment.type, 'pdf');
      expect(attachment.name, 'Invoice.pdf');
      expect(attachment.size, 2048);
    });

    test('fromJson parses attachment correctly', () {
      final json = {
        'url': 'https://example.com/image.jpg',
        'type': 'image',
        'name': 'Receipt.jpg',
        'size': 1024,
      };

      final attachment = Attachment.fromJson(json);

      expect(attachment.url, 'https://example.com/image.jpg');
      expect(attachment.type, 'image');
      expect(attachment.name, 'Receipt.jpg');
      expect(attachment.size, 1024);
    });

    test('toJson serializes attachment correctly', () {
      final attachment = Attachment(
        url: 'https://example.com/doc.docx',
        type: 'document',
        name: 'Contract.docx',
        size: 4096,
      );

      final json = attachment.toJson();

      expect(json['url'], 'https://example.com/doc.docx');
      expect(json['type'], 'document');
      expect(json['name'], 'Contract.docx');
      expect(json['size'], 4096);
    });
  });

  group('IncomeEntry - Edge Cases', () {
    test('handles zero amount', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Other',
        amount: 0.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.amount, 0.0);
    });

    test('handles very large amount', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Bonus',
        amount: 999999.99,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.amount, 999999.99);
    });

    test('handles multiple attachments', () {
      final attachments = [
        Attachment(url: 'url1', type: 'pdf', name: 'doc1.pdf', size: 1024),
        Attachment(url: 'url2', type: 'image', name: 'img1.jpg', size: 2048),
        Attachment(
            url: 'url3', type: 'document', name: 'doc2.docx', size: 4096),
      ];

      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Freelance',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        isRecurring: false,
        attachments: attachments,
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.attachments.length, 3);
    });

    test('handles high acknowledged count', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'household',
        privacyScope: 'full',
        isAcknowledged: true,
        acknowledgedCount: 10,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.acknowledgedCount, 10);
    });

    test('handles currency conversion with fx rate', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        category: 'Salary',
        amount: 5000.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        isAcknowledged: false,
        acknowledgedCount: 0,
        normalizedAmount: 4500.0,
        baseCurrency: 'EUR',
        fxRate: 0.9,
        isRecurring: false,
        attachments: [],
        createdAt: DateTime(2024, 1, 1),
        privacyRedacted: false,
      );

      expect(entry.amount, 5000.0);
      expect(entry.normalizedAmount, 4500.0);
      expect(entry.baseCurrency, 'EUR');
      expect(entry.fxRate, 0.9);
    });
  });
}
