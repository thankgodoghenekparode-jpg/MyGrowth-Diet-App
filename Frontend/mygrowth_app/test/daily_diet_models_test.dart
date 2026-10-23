import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/core/models/daily_diet_models.dart';

/// The payload the backend returns for `GET /api/v1/daily-diet?date=2027-03-17`
/// in the seeded 2027 programme, trimmed to the fields the client reads.
Map<String, dynamic> _bundleJson() => {
  'date': '2027-03-17',
  'dateInProgramme': true,
  'programme': {
    'id': 'p1',
    'title': 'Growth Diet Plan 2027',
    'year': 2027,
    'ministry': 'Healings Erhuvwuigho Azuike Ministry',
  },
  'monthlyPlan': {
    'id': 'm1',
    'month': 3,
    'year': 2027,
    'theme': 'The book of Acts',
    'prayerFocus': 'I have furtherance in my life by the Spirit.',
    'fastingGuidance': 'Wednesday and Saturday',
    'monthlyConfession': 'Teach me to number my days.',
  },
  'weeklyPlan': {
    'id': 'w1',
    'weekNumber': 3,
    'prayerDurationTargetMinutes': 45,
  },
  'progress': {'completed': 1, 'total': 11, 'ratio': 1 / 11},
  'sections': [
    {
      'id': 's1',
      'key': 'prayer',
      'label': 'Prayers',
      'description': 'Weekly and monthly prayer direction.',
      'behaviour': 'TIMER',
      'sortOrder': 1,
      'required': true,
      'allowNote': true,
      'trackCompletion': true,
      'status': 'COMPLETED',
      'content': {
        'id': 'c1',
        'sectionId': 's1',
        'date': '2027-03-14',
        'scope': 'WEEK',
        'title': 'Prayer - March (week 3)',
        'body': 'I have furtherance in my life by the Spirit.',
        'details': {
          'week': 3,
          'year': 2027,
          'month': 'March',
          'monthlyFocus': 'I have furtherance in my life by the Spirit.',
        },
        'materialIds': <String>[],
        'durationTargetMinutes': 45,
        'status': 'PUBLISHED',
      },
      'materials': <dynamic>[],
      'completion': {
        'id': 'cp1',
        'sectionId': 's1',
        'date': '2027-03-17',
        'status': 'COMPLETED',
        'actualDurationMinutes': 45,
        'note': 'Prayed at dawn.',
      },
    },
    {
      'id': 's2',
      'key': 'scripture_reading',
      'label': 'Scriptures reading',
      'behaviour': 'TEXT',
      'sortOrder': 2,
      'required': true,
      'allowNote': true,
      'trackCompletion': true,
      'status': 'NOT_STARTED',
      'content': {
        'id': 'c2',
        'sectionId': 's2',
        'date': '2027-03-17',
        'scope': 'DAY',
        'title': 'Acts 4-6',
        'body': '',
        'details': {
          'heading': 'The Book of Acts and the Book of Romans',
          'focus': 'Observe the work of the Holy Spirit in the early Church.',
          'note': 'Acts has 28 chapters and Romans has 16 chapters.',
          'reading': 'Acts 4-6',
          'dayOfMonth': 17,
          'month': 3,
          'year': 2027,
        },
        'materialIds': <String>[],
        'status': 'PUBLISHED',
      },
      'materials': <dynamic>[],
    },
    {
      'id': 's3',
      'key': 'literature_reading',
      'label': 'Literature daily read',
      'behaviour': 'MATERIAL',
      'sortOrder': 4,
      'required': true,
      'allowNote': true,
      'trackCompletion': true,
      'status': 'NOT_STARTED',
      'content': {
        'id': 'c3',
        'sectionId': 's3',
        'date': '2027-03-01',
        'scope': 'MONTH',
        'title': 'Literature - March 2027',
        'body': 'Financial Stewardship - Andrew Womack',
        // The seed stores a single object here, not a list.
        'details': {
          'books': {'title': 'Financial Stewardship', 'author': 'Andrew Womack'},
          'month': 'March',
          'year': 2027,
        },
        'materialIds': <String>[],
        'status': 'PUBLISHED',
      },
      'materials': <dynamic>[],
    },
    {
      'id': 's4',
      'key': 'audio_message',
      'label': 'Daily / weekly audio messages',
      'behaviour': 'MATERIAL',
      'sortOrder': 9,
      'required': false,
      'allowNote': true,
      'trackCompletion': true,
      'status': 'NOT_STARTED',
      'content': {
        'id': 'c4',
        'sectionId': 's4',
        'date': '2027-03-01',
        'scope': 'MONTH',
        'title': 'Audio messages - March 2027',
        'body': 'Stewards of Christ 1-5 by Pastor Healings E. Azuike',
        // The seed stores a single message here, not a list.
        'details': {
          'messages': 'Stewards of Christ 1-5 by Pastor Healings E. Azuike',
          'month': 'March',
        },
        'materialIds': <String>[],
        'status': 'PUBLISHED',
      },
      'materials': <dynamic>[],
    },
    {
      'id': 's5',
      'key': 'music',
      'label': 'Music',
      'behaviour': 'MATERIAL',
      'sortOrder': 11,
      'required': false,
      'allowNote': true,
      'trackCompletion': true,
      'status': 'NOT_STARTED',
      'content': null,
      'materials': <dynamic>[],
    },
  ],
};

void main() {
  group('DailyDietBundle', () {
    test('parses the seeded day bundle', () {
      final bundle = DailyDietBundle.fromJson(_bundleJson());

      expect(bundle.date, '2027-03-17');
      expect(bundle.dateInProgramme, isTrue);
      expect(bundle.programme?.year, 2027);
      expect(bundle.monthlyPlan?.theme, 'The book of Acts');
      expect(bundle.weeklyPlan?.prayerDurationTargetMinutes, 45);
      expect(bundle.progress.completed, 1);
      expect(bundle.progress.total, 11);
      expect(bundle.sections.length, 5);
    });

    test('a section carries its behaviour, scope and completion', () {
      final bundle = DailyDietBundle.fromJson(_bundleJson());
      final prayer = bundle.sections.firstWhere((s) => s.key == 'prayer');

      expect(prayer.behaviour, DailyDietBehaviour.timer);
      expect(prayer.isCompleted, isTrue);
      expect(prayer.completion?.actualDurationMinutes, 45);
      expect(prayer.completion?.note, 'Prayed at dawn.');
      expect(prayer.content?.scope, DailyDietScope.week);
      expect(prayer.content?.durationTargetMinutes, 45);
      expect(prayer.content?.monthlyFocus, isNotNull);
      expect(prayer.preview, 'Prayer - March (week 3)');
    });

    test('the scripture reading exposes the reading, heading and focus', () {
      final bundle = DailyDietBundle.fromJson(_bundleJson());
      final reading = bundle.sections.firstWhere(
        (s) => s.key == 'scripture_reading',
      );

      expect(reading.content?.scope, DailyDietScope.day);
      expect(reading.content?.reading, 'Acts 4-6');
      expect(
        reading.content?.heading,
        'The Book of Acts and the Book of Romans',
      );
      expect(reading.content?.focus, isNotNull);
      expect(reading.content?.readingNote, isNotNull);
    });

    test('a single object stored under books still reads as a list', () {
      final bundle = DailyDietBundle.fromJson(_bundleJson());
      final literature = bundle.sections.firstWhere(
        (s) => s.key == 'literature_reading',
      );

      expect(literature.content?.books.length, 1);
      expect(literature.content?.books.first['title'], 'Financial Stewardship');
      expect(literature.content?.books.first['author'], 'Andrew Womack');
    });

    test('a single message stored under messages still reads as a list', () {
      final bundle = DailyDietBundle.fromJson(_bundleJson());
      final audio = bundle.sections.firstWhere(
        (s) => s.key == 'audio_message',
      );

      expect(audio.content?.messages.length, 1);
      expect(
        audio.content?.messages.first,
        'Stewards of Christ 1-5 by Pastor Healings E. Azuike',
      );
    });

    test('a section with no content parses without a body', () {
      final bundle = DailyDietBundle.fromJson(_bundleJson());
      final music = bundle.sections.firstWhere((s) => s.key == 'music');

      expect(music.content, isNull);
      expect(music.isCompleted, isFalse);
      expect(music.behaviour, DailyDietBehaviour.material);
    });
  });

  group('DailyDietContent', () {
    test('a list of books parses into title and author', () {
      final content = DailyDietContent.fromJson({
        'id': 'c',
        'sectionId': 's',
        'date': '2027-03-01',
        'scope': 'MONTH',
        'title': 'Literature',
        'details': {
          'books': [
            {'title': 'Faithful Steward', 'author': 'A. Womack'},
            {'title': 'Only Believe'},
          ],
        },
        'status': 'PUBLISHED',
      });

      expect(content.books.length, 2);
      expect(content.books.first['author'], 'A. Womack');
      expect(content.books.last['author'], isNull);
    });

    test('a plain string detail still reads as a one-item list', () {
      final content = DailyDietContent.fromJson({
        'id': 'c',
        'sectionId': 's',
        'date': '2027-03-01',
        'scope': 'MONTH',
        'title': 'Proverbs',
        'details': {'books': 'Acts | Romans | Proverbs'},
        'status': 'PUBLISHED',
      });

      expect(content.books.length, 1);
      expect(content.books.first['title'], 'Acts | Romans | Proverbs');
    });

    test('the scope falls back to the day for an unknown value', () {
      final content = DailyDietContent.fromJson({
        'id': 'c',
        'sectionId': 's',
        'date': '2027-03-01',
        'scope': 'QUARTER',
        'title': 'x',
        'status': 'DRAFT',
      });

      expect(content.scope, DailyDietScope.day);
      expect(content.scope.wire, 'DAY');
    });

    test('the fasting guidance and songs read from their detail keys', () {
      final content = DailyDietContent.fromJson({
        'id': 'c',
        'sectionId': 's',
        'date': '2027-03-01',
        'scope': 'MONTH',
        'title': 'Fasting - March 2027',
        'details': {
          'guidance': 'Wednesday and Saturday, 6:00 a.m.-2:00 p.m.',
          'songs': ['Great is Thy Faithfulness', 'Amazing Grace'],
        },
        'status': 'PUBLISHED',
      });

      expect(
        content.guidance,
        'Wednesday and Saturday, 6:00 a.m.-2:00 p.m.',
      );
      expect(content.songs, ['Great is Thy Faithfulness', 'Amazing Grace']);
    });
  });

  group('AdminDailyDietContent', () {
    test('parses the admin content row', () {
      final row = AdminDailyDietContent.fromJson({
        'id': 'ac1',
        'sectionId': 's1',
        'date': '2027-06-06',
        'scope': 'WEEK',
        'title': 'Songs for the week',
        'body': '',
        'details': {'songs': ['Great is Thy Faithfulness', 'Amazing Grace']},
        'materialIds': ['f1'],
        'durationTargetMinutes': 30,
        'status': 'PUBLISHED',
        'publishedAt': '2027-06-01T00:00:00.000Z',
      });

      expect(row.scope, DailyDietScope.week);
      expect(row.scope.wire, 'WEEK');
      expect(row.isPublished, isTrue);
      expect(row.materialIds, ['f1']);
      expect(row.durationTargetMinutes, 30);
      expect(row.details?['songs'], isA<List<dynamic>>());
    });
  });

  group('DailyDietBehaviour', () {
    test('maps every behaviour the backend can send', () {
      expect(DailyDietBehaviour.fromJson('TEXT'), DailyDietBehaviour.text);
      expect(DailyDietBehaviour.fromJson('MATERIAL'), DailyDietBehaviour.material);
      expect(DailyDietBehaviour.fromJson('TIMER'), DailyDietBehaviour.timer);
      expect(DailyDietBehaviour.fromJson('TICK'), DailyDietBehaviour.tick);
      expect(DailyDietBehaviour.fromJson('REPORT'), DailyDietBehaviour.report);
      expect(DailyDietBehaviour.fromJson('PARTNER'), DailyDietBehaviour.partner);
      expect(DailyDietBehaviour.fromJson(null), DailyDietBehaviour.text);
    });

    test('the wire values match the backend enum', () {
      expect(DailyDietBehaviour.text.wire, 'TEXT');
      expect(DailyDietBehaviour.material.wire, 'MATERIAL');
      expect(DailyDietBehaviour.timer.wire, 'TIMER');
      expect(DailyDietBehaviour.tick.wire, 'TICK');
      expect(DailyDietBehaviour.report.wire, 'REPORT');
      expect(DailyDietBehaviour.partner.wire, 'PARTNER');
    });
  });
}
