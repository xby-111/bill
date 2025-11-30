/// 账单数据模型
/// 
/// 对应后端 [schemas/bill.py] 中的 BillResponse
/// 包含账单的完整信息，用于列表展示和详情页
class Bill {
  /// 账单唯一标识 (创建时为 null，由后端生成)
  final int? id;
  
  /// 金额 (单位: 元)
  final double amount;
  
  /// 账单类型: 'income'(收入) 或 'expense'(支出)
  final String billType;
  
  /// 分类: 如 '人工'、'材料'、'餐饮' 等
  final String category;
  
  /// 账单日期
  final DateTime date;
  
  /// 备注信息 (可选)
  final String? note;
  
  /// 工人姓名 (可选，用于记录临时工)
  final String? worker;
  
  /// 工作时长，单位: 小时 (可选)
  final double? durationHours;
  
  /// 时薪 (每小时单价，可选)
  final double? hourlyRate;
  
  /// 支付方式: '现金'、'微信'、'支付宝'、'银行转账' (可选)
  final String? payMethod;
  
  /// 所属用户 ID
  final int? userId;
  
  /// 创建时间
  final DateTime? createdAt;
  
  /// 更新时间
  final DateTime? updatedAt;

  Bill({
    this.id,
    required this.amount,
    required this.billType,
    required this.category,
    required this.date,
    this.note,
    this.worker,
    this.durationHours,
    this.payMethod,
    this.hourlyRate,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  /// 从 JSON 反序列化 (后端响应 → Dart 对象)
  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      billType: json['bill_type'] as String,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      worker: json['worker'] as String?,
      durationHours: json['duration_hours'] != null
          ? (json['duration_hours'] as num).toDouble()
          : null,
        hourlyRate: json['hourly_rate'] != null
          ? (json['hourly_rate'] as num).toDouble()
          : null,
      payMethod: json['pay_method'] as String?,
      userId: json['user_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// 序列化为 JSON (Dart 对象 → 发送给后端)
  /// 只包含创建账单所需的字段
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'bill_type': billType,
      'category': category,
      'date': date.toIso8601String(),
      if (note != null) 'note': note,
      if (worker != null) 'worker': worker,
      if (durationHours != null) 'duration_hours': durationHours,
      if (hourlyRate != null) 'hourly_rate': hourlyRate,
      if (payMethod != null) 'pay_method': payMethod,
    };
  }

  /// 创建当前对象的副本，可选择性修改部分字段
  /// 常用于更新账单时保留未修改的字段
  Bill copyWith({
    int? id,
    double? amount,
    String? billType,
    String? category,
    DateTime? date,
    String? note,
    String? worker,
    double? durationHours,
    double? hourlyRate,
    String? payMethod,
    int? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bill(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      billType: billType ?? this.billType,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      worker: worker ?? this.worker,
      durationHours: durationHours ?? this.durationHours,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      payMethod: payMethod ?? this.payMethod,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


/// 账单更新模型
/// 
/// 用于 PUT /bills/{id} 接口，所有字段均为可选
/// 只需传入需要修改的字段
class BillUpdate {
  final double? amount;
  final String? billType;
  final String? category;
  final DateTime? date;
  final String? note;
  final String? worker;
  final double? durationHours;
  final double? hourlyRate;
  final String? payMethod;

  BillUpdate({
    this.amount,
    this.billType,
    this.category,
    this.date,
    this.note,
    this.worker,
    this.durationHours,
    this.hourlyRate,
    this.payMethod,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (amount != null) map['amount'] = amount;
    if (billType != null) map['bill_type'] = billType;
    if (category != null) map['category'] = category;
    if (date != null) map['date'] = date!.toIso8601String();
    if (note != null) map['note'] = note;
    if (worker != null) map['worker'] = worker;
    if (durationHours != null) map['duration_hours'] = durationHours;
    if (hourlyRate != null) map['hourly_rate'] = hourlyRate;
    if (payMethod != null) map['pay_method'] = payMethod;
    return map;
  }
}


/// 月度收支统计模型
/// 
/// 对应 GET /bills/statistics/monthly 接口响应
class BillStatistics {
  /// 统计月份 (格式: YYYY-MM)
  final String month;
  
  /// 总收入
  final double totalIncome;
  
  /// 总支出
  final double totalExpense;
  
  /// 净额 (收入 - 支出)
  final double netAmount;

  BillStatistics({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netAmount,
  });

  factory BillStatistics.fromJson(Map<String, dynamic> json) {
    return BillStatistics(
      month: json['month'] as String,
      totalIncome: (json['total_income'] as num).toDouble(),
      totalExpense: (json['total_expense'] as num).toDouble(),
      netAmount: (json['net_amount'] as num).toDouble(),
    );
  }
}


/// 分类统计模型
/// 
/// 对应 GET /bills/statistics/category 接口响应
class CategoryStatistics {
  /// 分类名称
  final String category;
  
  /// 该分类总金额
  final double amount;
  
  /// 占比百分比 (0-100)
  final double percentage;

  CategoryStatistics({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  factory CategoryStatistics.fromJson(Map<String, dynamic> json) {
    return CategoryStatistics(
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}


/// 工人统计模型
/// 
/// 对应 GET /bills/statistics/worker 接口响应
/// 用于统计每个工人的工作情况
class WorkerStatistics {
  /// 工人姓名
  final String worker;
  
  /// 累计工作时长 (小时)
  final double totalHours;
  
  /// 累计支付金额 (元)
  final double totalAmount;
  
  /// 账单记录数
  final int billCount;

  WorkerStatistics({
    required this.worker,
    required this.totalHours,
    required this.totalAmount,
    required this.billCount,
  });

  factory WorkerStatistics.fromJson(Map<String, dynamic> json) {
    return WorkerStatistics(
      worker: json['worker'] as String,
      totalHours: (json['total_hours'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      billCount: json['bill_count'] as int,
    );
  }
}


/// 用户信息模型
/// 
/// 对应 GET /auth/me 接口响应
class User {
  final int id;
  final String username;
  final String email;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}


/// JWT 认证令牌模型
/// 
/// 对应 POST /auth/login 接口响应
class AuthToken {
  /// JWT 访问令牌
  final String accessToken;
  
  /// 令牌类型 (固定为 'bearer')
  final String tokenType;

  AuthToken({
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }
}
