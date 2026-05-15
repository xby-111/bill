import 'package:flutter_test/flutter_test.dart';
import 'package:family_work_ledger/services/speech_parser.dart';

void main() {
  group('SpeechParser', () {
    late SpeechParser parser;

    setUp(() {
      parser = SpeechParser();
    });

    group('工人识别', () {
      test('应该识别预设工人', () {
        final result = parser.parse('张师傅今天来了');
        expect(result.worker, '张师傅');
      });

      test('应该识别自定义工人', () {
        final result = parser.parse('李师傅今天来了');
        expect(result.worker, '李师傅');
      });

      test('应该识别带称呼的工人', () {
        final result = parser.parse('王五师傅今天来了');
        expect(result.worker, isNotNull);
        expect(result.worker, contains('王五'));
      });

      test('未识别工人时应返回 null', () {
        final result = parser.parse('今天有工作');
        expect(result.worker, isNull);
      });
    });

    group('工时识别', () {
      test('应该识别半工', () {
        final result = parser.parse('今天半工');
        expect(result.durationHours, 4.0);
      });

      test('应该识别大工', () {
        final result = parser.parse('今天大工');
        expect(result.durationHours, 8.0);
      });

      test('应该识别具体小时数', () {
        final result = parser.parse('工作了5小时');
        expect(result.durationHours, 5.0);
      });

      test('应该识别半小时格式', () {
        final result = parser.parse('工作了3个半小时');
        expect(result.durationHours, 3.5);
      });

      test('应该识别加班', () {
        final result = parser.parse('今天加班了', currentDuration: 8.0);
        expect(result.durationHours, 9.0);
      });

      test('应该识别具体加班时长', () {
        final result = parser.parse('今天加班了2小时', currentDuration: 8.0);
        expect(result.durationHours, 10.0);
      });
    });

    group('时薪识别', () {
      test('应该识别"每小时XX块"', () {
        final result = parser.parse('每小时30块');
        expect(result.hourlyRate, 30.0);
      });

      test('应该识别"XX块一小时"', () {
        final result = parser.parse('30块一小时');
        expect(result.hourlyRate, 30.0);
      });

      test('应该识别小数时薪', () {
        final result = parser.parse('每小时12.5块');
        expect(result.hourlyRate, 12.5);
      });
    });

    group('金额识别', () {
      test('应该识别"XX块钱"', () {
        final result = parser.parse('花了100块钱');
        expect(result.amount, 100.0);
      });

      test('应该识别"XX元"', () {
        final result = parser.parse('花了200元');
        expect(result.amount, 200.0);
      });

      test('应该识别小数金额', () {
        final result = parser.parse('花了50.5元');
        expect(result.amount, 50.5);
      });
    });

    group('时间识别', () {
      test('应该识别上午时间', () {
        final baseDate = DateTime(2025, 1, 1);
        final result = parser.parse('上午8点', baseDate: baseDate);
        expect(result.startDateTime, isNotNull);
        expect(result.startDateTime!.hour, 8);
      });

      test('应该识别下午时间', () {
        final baseDate = DateTime(2025, 1, 1);
        final result = parser.parse('下午2点', baseDate: baseDate);
        expect(result.startDateTime, isNotNull);
        expect(result.startDateTime!.hour, 14);
      });

      test('应该识别带分钟的时间', () {
        final baseDate = DateTime(2025, 1, 1);
        final result = parser.parse('8点30分', baseDate: baseDate);
        expect(result.startDateTime, isNotNull);
        expect(result.startDateTime!.hour, 8);
        expect(result.startDateTime!.minute, 30);
      });

      test('应该识别冒号格式时间', () {
        final baseDate = DateTime(2025, 1, 1);
        final result = parser.parse('9:30', baseDate: baseDate);
        expect(result.startDateTime, isNotNull);
        expect(result.startDateTime!.hour, 9);
        expect(result.startDateTime!.minute, 30);
      });
    });

    group('综合解析', () {
      test('应该解析完整句子', () {
        final baseDate = DateTime(2025, 1, 1);
        final result = parser.parse(
          '张师傅今天大工8小时，30块一小时',
          baseDate: baseDate,
        );

        expect(result.worker, '张师傅');
        expect(result.durationHours, 8.0);
        expect(result.hourlyRate, 30.0);
      });

      test('应该处理乱序输入', () {
        final baseDate = DateTime(2025, 1, 1);
        final result = parser.parse(
          '30块钱一小时，张师傅干了8小时',
          baseDate: baseDate,
        );

        expect(result.worker, '张师傅');
        expect(result.durationHours, 8.0);
        expect(result.hourlyRate, 30.0);
      });
    });

    group('金额计算', () {
      test('应该正确计算金额', () {
        final (amount, explanation) = SpeechParser.calculateAmount(30.0, 8.0);
        expect(amount, 240.0);
        expect(explanation, '30元/h × 8h');
      });

      test('应该处理小数计算', () {
        final (amount, explanation) = SpeechParser.calculateAmount(12.5, 4.5);
        expect(amount, 56.25);
        expect(explanation, '12.5元/h × 4.5h');
      });
    });

    group('hasData', () {
      test('有数据时应返回 true', () {
        final result = SpeechParseResult(worker: '张师傅');
        expect(result.hasData, true);
      });

      test('无数据时应返回 false', () {
        final result = SpeechParseResult();
        expect(result.hasData, false);
      });
    });
  });
}