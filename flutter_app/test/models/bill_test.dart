import 'package:flutter_test/flutter_test.dart';
import 'package:family_work_ledger/models/bill.dart';

void main() {
  group('Bill Model', () {
    group('fromJson', () {
      test('应该正确反序列化完整数据', () {
        final json = {
          'id': 1,
          'amount': 100.50,
          'bill_type': 'expense',
          'category': '人工',
          'date': '2025-01-01T12:00:00',
          'note': '测试备注',
          'name': '张师傅',
          'duration_hours': 8.0,
          'hourly_rate': 12.56,
          'pay_method': '现金',
          'user_id': 1,
          'created_at': '2025-01-01T10:00:00',
          'updated_at': '2025-01-01T10:00:00',
        };

        final bill = Bill.fromJson(json);

        expect(bill.id, 1);
        expect(bill.amount, 100.50);
        expect(bill.billType, 'expense');
        expect(bill.category, '人工');
        expect(bill.note, '测试备注');
        expect(bill.name, '张师傅');
        expect(bill.durationHours, 8.0);
        expect(bill.hourlyRate, 12.56);
        expect(bill.payMethod, '现金');
        expect(bill.userId, 1);
      });

      test('应该正确处理可选字段为 null', () {
        final json = {
          'id': 1,
          'amount': 100.50,
          'bill_type': 'expense',
          'category': '人工',
          'date': '2025-01-01T12:00:00',
          'user_id': 1,
          'created_at': '2025-01-01T10:00:00',
        };

        final bill = Bill.fromJson(json);

        expect(bill.note, isNull);
        expect(bill.name, isNull);
        expect(bill.durationHours, isNull);
        expect(bill.hourlyRate, isNull);
        expect(bill.payMethod, isNull);
        expect(bill.updatedAt, isNull);
      });

      test('应该正确处理小数金额', () {
        final json = {
          'id': 1,
          'amount': 100.5,
          'bill_type': 'expense',
          'category': '人工',
          'date': '2025-01-01T12:00:00',
          'user_id': 1,
          'created_at': '2025-01-01T10:00:00',
        };

        final bill = Bill.fromJson(json);
        expect(bill.amount, 100.5);
      });
    });

    group('toJson', () {
      test('应该正确序列化创建账单所需数据', () {
        final bill = Bill(
          amount: 100.50,
          billType: 'expense',
          category: '人工',
          date: DateTime(2025, 1, 1, 12, 0),
          note: '测试备注',
          name: '张师傅',
          durationHours: 8.0,
          hourlyRate: 12.56,
          payMethod: '现金',
        );

        final json = bill.toJson();

        expect(json['amount'], 100.50);
        expect(json['bill_type'], 'expense');
        expect(json['category'], '人工');
        expect(json['date'], '2025-01-01T12:00:00.000');
        expect(json['note'], '测试备注');
        expect(json['name'], '张师傅');
        expect(json['duration_hours'], 8.0);
        expect(json['hourly_rate'], 12.56);
        expect(json['pay_method'], '现金');
      });

      test('应该忽略 null 值字段', () {
        final bill = Bill(
          amount: 100.50,
          billType: 'expense',
          category: '人工',
          date: DateTime(2025, 1, 1, 12, 0),
        );

        final json = bill.toJson();

        expect(json.containsKey('note'), false);
        expect(json['name'], '未命名账单');
        expect(json.containsKey('duration_hours'), false);
        expect(json.containsKey('hourly_rate'), false);
        expect(json.containsKey('pay_method'), false);
      });
    });

    group('copyWith', () {
      test('应该正确复制并修改部分字段', () {
        final original = Bill(
          amount: 100.50,
          billType: 'expense',
          category: '人工',
          date: DateTime(2025, 1, 1, 12, 0),
        );

        final copied = original.copyWith(amount: 200.00);

        expect(copied.amount, 200.00);
        expect(copied.billType, original.billType);
        expect(copied.category, original.category);
        expect(copied.date, original.date);
      });

      test('应该保持未修改字段不变', () {
        final original = Bill(
          id: 1,
          amount: 100.50,
          billType: 'expense',
          category: '人工',
          date: DateTime(2025, 1, 1, 12, 0),
        );

        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.amount, original.amount);
        expect(copied.billType, original.billType);
        expect(copied.category, original.category);
        expect(copied.date, original.date);
      });
    });
  });

  group('BillUpdate Model', () {
    test('应该正确序列化更新数据', () {
      final update = BillUpdate(
        amount: 200.00,
        note: '更新后的备注',
      );

      final json = update.toJson();

      expect(json['amount'], 200.00);
      expect(json['note'], '更新后的备注');
      expect(json.containsKey('bill_type'), false);
      expect(json.containsKey('category'), false);
    });

    test('应该处理所有可选字段', () {
      final update = BillUpdate(
        amount: 200.00,
        billType: 'income',
        category: '材料',
        date: DateTime(2025, 1, 2, 12, 0),
        note: '备注',
        name: '李师傅',
        durationHours: 4.0,
        hourlyRate: 25.0,
        payMethod: '微信',
      );

      final json = update.toJson();

      expect(json.length, 9);
      expect(json['name'], '李师傅');
      expect(json['amount'], 200.00);
      expect(json['bill_type'], 'income');
      expect(json['category'], '材料');
    });
  });

  group('BillStatistics Model', () {
    test('应该正确反序列化统计数据', () {
      final json = {
        'month': '2025-01',
        'total_income': 5000.0,
        'total_expense': 3000.0,
        'net_amount': 2000.0,
      };

      final stats = BillStatistics.fromJson(json);

      expect(stats.month, '2025-01');
      expect(stats.totalIncome, 5000.0);
      expect(stats.totalExpense, 3000.0);
      expect(stats.netAmount, 2000.0);
    });
  });

  group('CategoryStatistics Model', () {
    test('应该正确反序列化分类统计', () {
      final json = {
        'category': '人工',
        'amount': 1500.0,
        'percentage': 50.0,
      };

      final stats = CategoryStatistics.fromJson(json);

      expect(stats.category, '人工');
      expect(stats.amount, 1500.0);
      expect(stats.percentage, 50.0);
    });
  });

  group('NameStatistics Model', () {
    test('应该正确反序列化名称统计', () {
      final json = {
        'name': '张师傅',
        'total_hours': 40.0,
        'total_amount': 5000.0,
        'bill_count': 5,
      };

      final stats = NameStatistics.fromJson(json);

      expect(stats.name, '张师傅');
      expect(stats.totalHours, 40.0);
      expect(stats.totalAmount, 5000.0);
      expect(stats.billCount, 5);
    });
  });

  group('User Model', () {
    test('应该正确反序列化用户数据', () {
      final json = {
        'id': 1,
        'username': 'testuser',
        'email': 'test@example.com',
        'created_at': '2025-01-01T10:00:00',
        'updated_at': '2025-01-01T10:00:00',
      };

      final user = User.fromJson(json);

      expect(user.id, 1);
      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
    });

    test('应该处理可选 updated_at 为 null', () {
      final json = {
        'id': 1,
        'username': 'testuser',
        'email': 'test@example.com',
        'created_at': '2025-01-01T10:00:00',
      };

      final user = User.fromJson(json);
      expect(user.updatedAt, isNull);
    });
  });

  group('AuthToken Model', () {
    test('应该正确反序列化令牌', () {
      final json = {
        'access_token': 'test_token_123',
        'token_type': 'bearer',
      };

      final token = AuthToken.fromJson(json);

      expect(token.accessToken, 'test_token_123');
      expect(token.tokenType, 'bearer');
    });
  });
}