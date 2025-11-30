import 'package:flutter/material.dart';
import 'pages/add_bill_page.dart';
import 'config/app_config.dart';

void main() {
  runApp(const FamilyLedgerApp());
}

class FamilyLedgerApp extends StatelessWidget {
  const FamilyLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '版本 ${AppConfig.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddBillPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('记工时'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('账单列表功能开发中...')),
                );
              },
              icon: const Icon(Icons.list),
              label: const Text('查看账单'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('统计功能开发中...')),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('统计分析'),
            ),
          ],
        ),
      ),
    );
  }
}
