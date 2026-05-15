import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/add_bill_page.dart';
import 'pages/login_page.dart';
import 'pages/bill_list_page.dart';
import 'pages/statistics_page.dart';
import 'pages/project_list_page.dart';
import 'config/app_config.dart';
import 'services/auth_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: const FamilyLedgerApp(),
    ),
  );
}

class FamilyLedgerApp extends StatelessWidget {
  const FamilyLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2), // 更深沉稳重的蓝色
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF0288D1),
          surface: const Color(0xFFF5F7FA), // 浅灰背景，不那么刺眼
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // 全局背景色
        
        // 1. 全局字体配置
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, height: 1.5), 
          bodyLarge: TextStyle(fontSize: 18, height: 1.5),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.15),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
        ),

        // 2. AppBar 
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent, // 透明背景，依靠内容区的颜色
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
          iconTheme: IconThemeData(color: Color(0xFF1A1C1E)),
        ),

        // 3. 输入框 - 更现代的Filled样式
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // 默认无边框，纯净风格
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1), // 浅灰边框
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2), // 聚焦时高亮
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          prefixIconColor: Colors.grey[600],
          labelStyle: TextStyle(color: Colors.grey[700]),
        ),

        // 4. 卡片
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),

        // 5. 列表项
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          minVerticalPadding: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        
        // 6. 按钮
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(width: 1.5),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// 认证包装器
/// 
/// 根据登录状态显示不同页面
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // 正在检查登录状态
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载...'),
                ],
              ),
            ),
          );
        }

        // 已登录 - 显示主页
        if (auth.isAuthenticated) {
          return const HomePage();
        }

        // 未登录 - 显示登录入口页
        return const WelcomePage();
      },
    );
  }
}

/// 欢迎页（未登录时显示）
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void _goToLogin(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    
    if (result == true && context.mounted) {
      // 登录成功，刷新认证状态
      context.read<AuthProvider>().onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Logo
              const Icon(
                Icons.account_balance_wallet,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                AppConfig.appName,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '简单高效的家庭记账工具',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const Spacer(),
              // 功能亮点
              _FeatureItem(
                icon: Icons.mic,
                title: '语音记账',
                description: '说一句话完成记录',
              ),
              const SizedBox(height: 12),
              _FeatureItem(
                icon: Icons.camera_alt,
                title: '拍照识别',
                description: '拍摄单据自动提取信息',
              ),
              const SizedBox(height: 12),
              _FeatureItem(
                icon: Icons.bar_chart,
                title: '统计分析',
                description: '清晰了解收支情况',
              ),
              const Spacer(),
              // 登录按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _goToLogin(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('登录 / 注册', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '版本 ${AppConfig.version}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              description,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

/// 主页（已登录后显示）
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. 顶部大标题区域（代替传统AppBar）
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          '欢迎回来，',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.username ?? '用户',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
               IconButton(
                 icon: const Icon(Icons.logout, color: Colors.white),
                 onPressed: () => _logout(context),
               ),
            ],
          ),

          // 2. 功能网格区域
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240, // 设定最大宽度，让其在不同屏幕自动计算列数
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate(
                [
                  _MenuCard(
                    title: '记工时',
                    subtitle: '快速记录收入',
                    icon: Icons.add_circle_outline,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBillPage())),
                  ),
                  _MenuCard(
                    title: '项目管理',
                    subtitle: '管理工程项目',
                    icon: Icons.folder_open,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectListPage())),
                  ),
                  _MenuCard(
                    title: '所有账单',
                    subtitle: '查看历史记录',
                    icon: Icons.receipt_long,
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillListPage())),
                  ),
                  _MenuCard(
                    title: '统计分析',
                    subtitle: '收支报表',
                    icon: Icons.bar_chart,
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsPage())),
                  ),
                ],
              ),
            ),
          ),
          
          // 3. 底部提示
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Text(
                  '让记账更简单',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, // 使用扁平风格+浅色背景
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
