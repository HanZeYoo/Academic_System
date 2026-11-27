import 'package:academic_system/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final referenceDate = DateTime(2026, 11, 27);

  group('Announcement 30-day auto-archive', () {
    test('keeps active unpinned announcement within 29 days', () {
      final a = {
        'id': 1,
        'status': 'Active',
        'is_pinned': 0,
        'date_posted': '2026-10-29',
      };
      expect(DatabaseHelper.shouldAutoArchiveAnnouncement(a, now: referenceDate), isFalse);
      expect(DatabaseHelper.isAnnouncementArchived(a, now: referenceDate), isFalse);
    });

    test('auto-archives unpinned announcement at exactly 30 days', () {
      final a = {
        'id': 2,
        'status': 'Active',
        'is_pinned': 0,
        'date_posted': '2026-10-28',
      };
      expect(DatabaseHelper.shouldAutoArchiveAnnouncement(a, now: referenceDate), isTrue);
      expect(DatabaseHelper.isAnnouncementArchived(a, now: referenceDate), isTrue);
    });

    test('auto-archives unpinned announcement older than 30 days', () {
      final a = {
        'id': 3,
        'status': 'Active',
        'is_pinned': 0,
        'date_posted': '2026-09-28',
      };
      expect(DatabaseHelper.shouldAutoArchiveAnnouncement(a, now: referenceDate), isTrue);
      expect(DatabaseHelper.isAnnouncementArchived(a, now: referenceDate), isTrue);
    });

    test('exempts pinned announcements even if older than 30 days', () {
      final a = {
        'id': 4,
        'status': 'Active',
        'is_pinned': 1,
        'date_posted': '2026-08-29',
      };
      expect(DatabaseHelper.shouldAutoArchiveAnnouncement(a, now: referenceDate), isFalse);
      expect(DatabaseHelper.isAnnouncementArchived(a, now: referenceDate), isFalse);
    });

    test('recognizes already archived announcements without re-triggering auto-archive', () {
      final a = {
        'id': 5,
        'status': 'Archived',
        'is_pinned': 0,
        'date_posted': '2026-11-27',
      };
      expect(DatabaseHelper.shouldAutoArchiveAnnouncement(a, now: referenceDate), isFalse);
      expect(DatabaseHelper.isAnnouncementArchived(a, now: referenceDate), isTrue);
    });

    test('returns false safely for missing or malformed date_posted', () {
      expect(
        DatabaseHelper.shouldAutoArchiveAnnouncement(
          {'status': 'Active', 'is_pinned': 0, 'date_posted': null},
          now: referenceDate,
        ),
        isFalse,
      );
      expect(
        DatabaseHelper.shouldAutoArchiveAnnouncement(
          {'status': 'Active', 'is_pinned': 0, 'date_posted': 'not-a-date'},
          now: referenceDate,
        ),
        isFalse,
      );
    });
  });
}
