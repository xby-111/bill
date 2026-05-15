import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/api_service.dart';
import 'add_bill_page.dart';
import 'bill_history_page.dart';

class BillDetailPage extends StatefulWidget {
  final Bill bill;

  const BillDetailPage({super.key, required this.bill});

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  late Bill _bill;

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
  }

  Future<void> _refresh() async {
    try {
      final newBill = await apiService.getBill(_bill.id!);
      setState(() => _bill = newBill);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账单'),
        content: const Text('确定要删除这条记录吗？删除操作也会被记录在历史中，可以恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await apiService.deleteBill(_bill.id!);
      if (mounted) {
        Navigator.pop(context, true); // 返回并刷新列表
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final isExpense = _bill.billType == 'expense';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '修改历史',
            onPressed: () async {
              final restored = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BillHistoryPage(billId: _bill.id!)),
              );
              if (restored == true) _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddBillPage(editBill: _bill)),
              );
              if (updated == true) _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '删除',
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 金额大卡片
          Card(
            color: isExpense ? Colors.red.shade50 : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(_bill.category, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '${isExpense ? '-' : '+'}${_bill.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 36, 
                      fontWeight: FontWeight.bold,
                      color: isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(df.format(_bill.date), style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 详细信息列表
          _buildInfoTile(Icons.person, '姓名', _bill.name ?? '未命名'),
          if (_bill.durationHours != null)
            _buildInfoTile(Icons.access_time, '工时', '${_bill.durationHours} 小时'),
          if (_bill.hourlyRate != null)
            _buildInfoTile(Icons.payments_outlined, '时薪', '¥${_bill.hourlyRate}/小时'),
          _buildInfoTile(Icons.payment, '支付方式', _bill.payMethod ?? '未记录'),
          
          const Divider(height: 32),
          const Text('备注', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _bill.note?.isNotEmpty == true ? _bill.note! : '无备注',
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
