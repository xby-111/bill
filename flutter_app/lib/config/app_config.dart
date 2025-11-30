class AppConfig {
  // API 地址 - 模拟器: 10.0.2.2:8000 | 真机: 替换为电脑 IP
  static const String apiBaseUrl = 'http://192.168.1.100:8000';

  static const String appName = '家庭记账';
  static const String version = '1.0.0';

  static const List<String> defaultWorkers = ['张师傅', '李阿姨', '王叔叔'];
  static const List<String> defaultCategories = ['人工', '材料', '餐饮', '交通', '水电', '维修', '其他'];
  static const List<String> payMethods = ['现金', '微信', '支付宝', '银行转账'];
}
