import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/api_service.dart';

class BillHistoryPage extends StatefulWidget {
  final int billId;

  const BillHistoryPage({super.key, required this.billId});

  @override
  State<BillHistoryPage> createState() => _BillHistoryPageState();
}

class _BillHistoryPageState extends State<BillHistoryPage> {
  List<BillHistory>? _history;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final list = await apiService.getBillHistory(widget.billId);
      setState(() {
        _history = list;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载历史失败: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restore(int historyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认回滚'),
        content: const Text('确定要将账单恢复到这个版本吗？当前的内容将会被覆盖（但会作为新的历史记录保存）。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定恢复')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await apiService.restoreBillVersion(historyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回滚成功')));
        Navigator.pop(context, true); // 返回上一页并通知刷新
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('回滚失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改历史')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history == null || _history!.isEmpty
              ? const Center(child: Text('暂无修改记录'))
              : ListView.builder(
                  itemCount: _history!.length,
                  itemBuilder: (ctx, i) {
                    final item = _history![i];
                    final df = DateFormat('yyyy-MM-dd HH:mm');
                    final isDelete = item.operationType == 'DELETE';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDelete ? Colors.red.shade100 : Colors.blue.shade100,
                          child: Icon(isDelete ? Icons.delete : Icons.edit, color: Colors.black54),
                        ),
                        title: Text(df.format(item.operatedAt)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('操作: ${isDelete ? '删除' : '修改'}'),
                            const SizedBox(height: 4),
                            Text(
                              '当时数据: ${item.category} / ¥${item.amount} / ${item.name ?? "无名称"}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            if (item.note != null && item.note!.isNotEmpty)
                              Text('备注: ${item.note}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: () => _restore(item.id),
                          child: const Text('恢复此版'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
