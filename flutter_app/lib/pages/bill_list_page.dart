import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/api_service.dart';
import 'bill_detail_page.dart';

class BillListPage extends StatefulWidget {
  final int? projectId;
  final String? projectName;
  final String? worker; // 按姓名筛选
  
  const BillListPage({
    super.key, 
    this.projectId,
    this.projectName,
    this.worker,
  });

  @override
  State<BillListPage> createState() => _BillListPageState();
}

class _BillListPageState extends State<BillListPage> {
  final List<Bill> _bills = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 20;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBills(refresh: true);
  }

  Future<void> _loadBills({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
      _bills.clear();
      setState(() => _isLoading = true);
    }

    try {
      final newBills = await apiService.getBills(
        skip: _page * _pageSize,
        limit: _pageSize,
        projectId: widget.projectId,
        worker: widget.worker,
      );

      setState(() {
        _bills.addAll(newBills);
        _hasMore = newBills.length == _pageSize;
        _page++;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName != null ? '${widget.projectName} - 账单' : '账单列表'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadBills(refresh: true),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _bills.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadBills(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_bills.isEmpty) {
      return const Center(child: Text('暂无账单记录'));
    }

    return ListView.builder(
      itemCount: _bills.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _bills.length) {
          _loadBills();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final bill = _bills[index];
        return _buildBillItem(bill);
      },
    );
  }

  Widget _buildBillItem(Bill bill) {
    final isExpense = bill.billType == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final sign = isExpense ? '-' : '+';
    final df = DateFormat('yyyy-MM-dd HH:mm');
    
    // 显示姓名，如果没有则显示"未命名"
    final displayName = bill.name?.isNotEmpty == true ? bill.name! : '未命名';

    return Card(
      // margin 由 CardTheme 统一控制，这里移除以保持一致
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 增加内部内边距
        leading: CircleAvatar(
          radius: 24, // 稍微大一点的图标
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isExpense ? Icons.remove : Icons.add,
            color: color,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            // 直接显示姓名作为主标题
            Flexible(
              child: Text(
                displayName, 
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (bill.durationHours != null && bill.durationHours! > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${bill.durationHours!.toStringAsFixed(1)}h',
                  style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8), // 增加标题和副标题的间距
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                df.format(bill.date),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              if (bill.note != null && bill.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  bill.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Text(
          '$sign${bill.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20, // 增大金额字体
          ),
        ),
        onTap: () async {
          // 跳转详情页，如果返回 true 说明有删除或修改，需要刷新
          final needRefresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BillDetailPage(bill: bill)),
          );
          if (needRefresh == true) {
            _loadBills(refresh: true);
          }
        },
      ),
    );
  }
}
