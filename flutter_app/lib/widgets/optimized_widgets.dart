/// 性能优化 Widget 组件库
/// 
/// 提供高性能的列表项和常用 UI 组件
/// 特性：
/// - const 构造函数优化
/// - RepaintBoundary 隔离重绘
/// - 懒加载和缓存优化
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';

/// 高性能账单列表项
/// 
/// 使用 RepaintBoundary 隔离重绘区域
/// 支持 const 构造（除 bill 参数外）
class OptimizedBillListItem extends StatelessWidget {
  final Bill bill;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const OptimizedBillListItem({
    super.key,
    required this.bill,
    this.onTap,
    this.onLongPress,
  });
  
  @override
  Widget build(BuildContext context) {
    // 使用 RepaintBoundary 隔离重绘
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _BillItemContent(bill: bill),
          ),
        ),
      ),
    );
  }
}

/// 账单项内容（内部组件）
class _BillItemContent extends StatelessWidget {
  final Bill bill;
  
  // 静态日期格式化器，避免重复创建
  static final DateFormat _dateFormat = DateFormat('MM-dd HH:mm');
  
  const _BillItemContent({required this.bill});
  
  @override
  Widget build(BuildContext context) {
    final isExpense = bill.billType == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final sign = isExpense ? '-' : '+';
    
    return Row(
      children: [
        // 图标
        _buildIcon(isExpense, color),
        const SizedBox(width: 12),
        // 内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTitle(),
              const SizedBox(height: 4),
              _buildSubtitle(),
            ],
          ),
        ),
        // 金额
        _buildAmount(sign, color),
      ],
    );
  }
  
  Widget _buildIcon(bool isExpense, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isExpense ? Icons.arrow_downward : Icons.arrow_upward,
        color: color,
        size: 20,
      ),
    );
  }
  
  Widget _buildTitle() {
    return Row(
      children: [
        Text(
          bill.category,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        if (bill.name != null && bill.name!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              bill.name!,
              style: const TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildSubtitle() {
    return Text(
      _dateFormat.format(bill.date),
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    );
  }
  
  Widget _buildAmount(String sign, Color color) {
    return Text(
      '$sign${bill.amount.toStringAsFixed(2)}',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}


/// 优化的分页列表控制器
class PaginationController<T> extends ChangeNotifier {
  final Future<List<T>> Function(int page, int pageSize) fetchPage;
  final int pageSize;
  
  List<T> _items = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  
  PaginationController({
    required this.fetchPage,
    this.pageSize = 20,
  });
  
  List<T> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;
  
  /// 加载第一页（刷新）
  Future<void> refresh() async {
    _currentPage = 0;
    _hasMore = true;
    _items = [];
    _error = null;
    notifyListeners();
    await loadMore();
  }
  
  /// 加载更多
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final newItems = await fetchPage(_currentPage, pageSize);
      _items.addAll(newItems);
      _hasMore = newItems.length == pageSize;
      _currentPage++;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 移除项
  void removeItem(T item) {
    _items.remove(item);
    notifyListeners();
  }
  
  /// 更新项
  void updateItem(int index, T item) {
    if (index >= 0 && index < _items.length) {
      _items[index] = item;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _items.clear();
    super.dispose();
  }
}


/// 分页列表 Widget
class PaginatedListView<T> extends StatelessWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget Function(String error)? errorBuilder;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  
  const PaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.emptyWidget,
    this.loadingWidget,
    this.errorBuilder,
    this.padding,
    this.physics,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // 初始加载状态
        if (controller.isLoading && controller.items.isEmpty) {
          return loadingWidget ?? const Center(child: CircularProgressIndicator());
        }
        
        // 错误状态
        if (controller.error != null && controller.items.isEmpty) {
          if (errorBuilder != null) {
            return errorBuilder!(controller.error!);
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(controller.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        
        // 空状态
        if (controller.isEmpty) {
          return emptyWidget ?? const Center(child: Text('暂无数据'));
        }
        
        // 列表
        return ListView.builder(
          padding: padding,
          physics: physics,
          itemCount: controller.items.length + (controller.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // 加载更多指示器
            if (index == controller.items.length) {
              // 触发加载
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.loadMore();
              });
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            return itemBuilder(context, controller.items[index], index);
          },
        );
      },
    );
  }
}


/// 骨架屏加载效果
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  
  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius,
  });
  
  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(_animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}


/// 账单列表骨架屏
class BillListSkeleton extends StatelessWidget {
  final int itemCount;
  
  const BillListSkeleton({super.key, this.itemCount = 5});
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const _BillSkeletonItem(),
    );
  }
}

class _BillSkeletonItem extends StatelessWidget {
  const _BillSkeletonItem();
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const SkeletonLoader(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(
                    width: 100,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  SkeletonLoader(
                    width: 60,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            SkeletonLoader(
              width: 60,
              height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
