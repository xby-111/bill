import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import 'bill_list_page.dart';

enum DateFilterMode { singleDay, dateRange, monthRange }

class StatisticsPage extends StatefulWidget {
  final int? defaultProjectId;

  const StatisticsPage({super.key, this.defaultProjectId});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateFilterMode _filterMode = DateFilterMode.singleDay;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedDateRange;
  late DateTime _startMonth;
  late DateTime _endMonth;
  bool _isLoading = true;
  BillStatistics? _stats;
  List<NameStatistics> _nameStats = []; // 改为人员统计
  String? _error;

  // 项目筛选
  List<Project> _projects = [];
  int? _selectedProjectId;
  bool _loadingProjects = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedDateRange = DateTimeRange(
      start: _selectedDate.subtract(const Duration(days: 6)),
      end: _selectedDate,
    );
    _startMonth = DateTime(now.year, now.month);
    _endMonth = _startMonth;
    _selectedProjectId = widget.defaultProjectId;
    _initData();
  }

  Future<void> _initData() async {
    await _loadProjects();
    await _loadData();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await apiService.getProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _loadingProjects = false;
          
          // 如果没有指定默认项目且有项目可选，设置第一个项目为默认
          if (widget.defaultProjectId == null && _projects.isNotEmpty && _selectedProjectId == null) {
            _selectedProjectId = _projects.first.id;
          }
        });
        
        // 如果设置了默认项目，重新加载数据
        if (widget.defaultProjectId == null && _projects.isNotEmpty && _selectedProjectId != null) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProjects = false);
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? dateParam;
      String? monthParam;
      String? startDateParam;
      String? endDateParam;
      String? startMonthParam;
      String? endMonthParam;

      switch (_filterMode) {
        case DateFilterMode.singleDay:
          dateParam = DateFormat('yyyy-MM-dd').format(_selectedDate);
          break;
        case DateFilterMode.dateRange:
          final range = _selectedDateRange ?? _defaultDateRange();
          _selectedDateRange = range;
          startDateParam = DateFormat('yyyy-MM-dd').format(range.start);
          endDateParam = DateFormat('yyyy-MM-dd').format(range.end);
          break;
        case DateFilterMode.monthRange:
          startMonthParam = DateFormat('yyyy-MM').format(_startMonth);
          endMonthParam = DateFormat('yyyy-MM').format(_endMonth);
          break;
      }

      // 并行请求两个接口 - 使用统一的筛选参数
      final results = await Future.wait([
        apiService.getMonthlyStatistics(
          month: monthParam,
          date: dateParam,
          startDate: startDateParam,
          endDate: endDateParam,
          startMonth: startMonthParam,
          endMonth: endMonthParam,
          projectId: _selectedProjectId,
        ),
        apiService.getNameStatistics(
          month: monthParam,
          date: dateParam,
          startDate: startDateParam,
          endDate: endDateParam,
          startMonth: startMonthParam,
          endMonth: endMonthParam,
          projectId: _selectedProjectId,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as BillStatistics;
        _nameStats = results[1] as List<NameStatistics>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  DateTimeRange _defaultDateRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
  }

  void _changeFilterMode(DateFilterMode mode) {
    if (_filterMode == mode) return;
    setState(() {
      _filterMode = mode;
      if (mode == DateFilterMode.singleDay) {
        _selectedDate = DateTime.now();
      } else if (mode == DateFilterMode.dateRange) {
        _selectedDateRange ??= _defaultDateRange();
      } else if (mode == DateFilterMode.monthRange) {
        final now = DateTime.now();
        _startMonth = DateTime(now.year, now.month);
        _endMonth = _startMonth;
      }
    });
    _loadData();
  }

  Widget _buildSelectorBody() {
    switch (_filterMode) {
      case DateFilterMode.singleDay:
        return Row(
          key: const ValueKey('singleDay'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeDate(-1),
            ),
            TextButton(
              onPressed: _pickDate,
              child: Text(
                DateFormat('yyyy-MM-dd').format(_selectedDate),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeDate(1),
            ),
          ],
        );

      case DateFilterMode.dateRange:
        return Row(
          key: const ValueKey('dateRange'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                _selectedDateRange != null
                    ? '${DateFormat('MM-dd').format(_selectedDateRange!.start)} 至 ${DateFormat('MM-dd').format(_selectedDateRange!.end)}'
                    : '选择日期范围',
              ),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDateRange: _selectedDateRange,
                );
                if (picked != null) {
                  setState(() => _selectedDateRange = picked);
                  _loadData();
                }
              },
            ),
          ],
        );

      case DateFilterMode.monthRange:
        return Column(
          key: const ValueKey('monthRange'),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('起始月份: '),
                TextButton(
                  onPressed: () => _pickMonth(true),
                  child: Text(DateFormat('yyyy-MM').format(_startMonth)),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('结束月份: '),
                TextButton(
                  onPressed: () => _pickMonth(false),
                  child: Text(DateFormat('yyyy-MM').format(_endMonth)),
                ),
              ],
            ),
          ],
        );
    }
  }

  Future<void> _pickMonth(bool isStart) async {
    final initial = isStart ? _startMonth : _endMonth;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        final monthDate = DateTime(picked.year, picked.month);
        if (isStart) {
          _startMonth = monthDate;
          if (_endMonth.isBefore(_startMonth)) {
            _endMonth = _startMonth;
          }
        } else {
          _endMonth = monthDate;
          if (_startMonth.isAfter(_endMonth)) {
            _startMonth = _endMonth;
          }
        }
      });
      _loadData();
    }
  }

  String get _currentFilterLabel {
    switch (_filterMode) {
      case DateFilterMode.singleDay:
        return DateFormat('yyyy年MM月dd日').format(_selectedDate);
      case DateFilterMode.dateRange:
        if (_selectedDateRange != null) {
          return '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} 至 ${DateFormat('MM-dd').format(_selectedDateRange!.end)}';
        }
        return '日期范围';
      case DateFilterMode.monthRange:
        return '${DateFormat('yyyy-MM').format(_startMonth)} 至 ${DateFormat('yyyy-MM').format(_endMonth)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('统计分析',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), // 统计图表宽一点更好看
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // 顶部筛选区 - 卡片包裹
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          child: Column(
                            children: [
                              _buildFilterSelector(),
                              // 如果是从项目进入，显示项目名称（不可切换）
                              if (widget.defaultProjectId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.folder_outlined, 
                                            size: 18,
                                            color: Theme.of(context).colorScheme.onPrimaryContainer),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _projects.where((p) => p.id == widget.defaultProjectId).isNotEmpty
                                                ? _projects.firstWhere((p) => p.id == widget.defaultProjectId).name
                                                : '当前项目',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              // 否则显示项目选择器
                              else if (!_loadingProjects && _projects.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int?>(
                                        value: _selectedProjectId,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down),
                                        hint: const Text('所有项目'),
                                        items: [
                                          const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('所有项目',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                          ..._projects
                                              .map((p) => DropdownMenuItem(
                                                    value: p.id,
                                                    child: Text(p.name),
                                                  )),
                                        ],
                                        onChanged: (val) {
                                          setState(
                                              () => _selectedProjectId = val);
                                          _loadData();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_isLoading)
                        const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()))
                      else if (_error != null)
                        Center(
                          child: Column(
                            children: [
                              Text('加载失败: $_error',
                                  style: const TextStyle(color: Colors.red)),
                              TextButton(
                                  onPressed: _loadData,
                                  child: const Text('重试')),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            if (_stats != null) _buildOverviewCard(),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Container(
                                    width: 4,
                                    height: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  '人员工时统计',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_nameStats.isNotEmpty)
                              _buildWorkerList()
                            else
                              const SizedBox(
                                height: 100,
                                child: Center(
                                    child: Text('当前筛选暂无人员工时数据',
                                        style: TextStyle(color: Colors.grey))),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSelector() {
    final selections = DateFilterMode.values
        .map((mode) => _filterMode == mode)
        .toList(growable: false);

    return Column(
      children: [
        ToggleButtons(
          isSelected: selections,
          borderRadius: BorderRadius.circular(8),
          constraints: const BoxConstraints(minWidth: 80, minHeight: 36),
          onPressed: (index) => _changeFilterMode(DateFilterMode.values[index]),
          children: const [
            Text('单日'),
            Text('多日'),
            Text('多月'),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildSelectorBody(),
        ),
      ],
    );
  }

  // ... (省略部分未变动的 selector helper methods, 它们会复用原有的逻辑，只是外层容器变了) ...

  // 重写 OverviewCard 使其更美观
  Widget _buildOverviewCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentFilterLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('收支概览',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItemWhite('总收入', _stats!.totalIncome),
                Container(width: 1, height: 40, color: Colors.white24),
                _buildStatItemWhite('总支出', _stats!.totalExpense),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('结余',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  Text(
                    '¥${_stats!.netAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItemWhite(String label, double amount) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // 重写 WorkerList 样式
  Widget _buildWorkerList() {
    // 按金额降序排列
    final sortedStats = List<NameStatistics>.from(_nameStats)
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return Column(
      children: sortedStats.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final hourlyRate =
            item.totalHours > 0 ? item.totalAmount / item.totalHours : 0.0;

        return Card(
          elevation: 0, // 使用扁平风格
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // 排名标识
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: index < 3
                        ? const Color(0xFFFFC107)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index < 3 ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 姓名信息
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BillListPage(
                            projectId: _selectedProjectId,
                            projectName: _selectedProjectId != null
                                ? '${item.name} 的账单'
                                : '${item.name} 的账单',
                            worker: item.name,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.billCount} 笔记录',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),

                // 数据
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${item.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.totalHours.toStringAsFixed(1)}h · ¥${hourlyRate.toStringAsFixed(0)}/h',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
