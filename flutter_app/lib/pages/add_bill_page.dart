import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../models/bill.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import 'project_list_page.dart';

class AddBillPage extends StatefulWidget {
  final Bill? editBill; // 传入此参数即为编辑模式
  final int? defaultProjectId; // 默认选中的项目ID

  const AddBillPage({super.key, this.editBill, this.defaultProjectId});

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _amountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // 姓名输入
  final _noteCtrl = TextEditingController();
  final _customPayMethodCtrl = TextEditingController(); // 自定义支付方式
  final _hourlyRateCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(); // 工时输入控制器

  DateTime _date = DateTime.now();
  String _billType = 'expense';
  bool _submitting = false;
  bool _hasSubmitted = false; // 标记是否已成功提交，防止dispose时重新保存草稿
  bool _amountManuallyEdited = false;
  bool _isUpdatingAmountProgrammatically = false;
  String? _calcExplanation;
  Timer? _draftDebounce;
  Timer? _timeUpdateTimer; // 时间自动更新定时器

  // 支付方式选项
  static const List<String> _payMethods = ['现金', '微信', '支付宝', '银行卡', '其他'];
  String _selectedPayMethod = '现金';

  // 项目相关
  List<Project> _projects = [];
  int? _selectedProjectId;
  bool _loadingProjects = true;

  bool get _isEditing => widget.editBill != null;

  // 获取工时值
  double get _duration {
    final text = _durationCtrl.text.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onFieldChange);
    _nameCtrl.addListener(_onFieldChange);
    _noteCtrl.addListener(_onFieldChange);
    _customPayMethodCtrl.addListener(_onFieldChange);
    _durationCtrl.addListener(_handleDurationChange); // 工时变化监听
    _hourlyRateCtrl.addListener(_handleHourlyRateChange);

    // 新增模式自动同步当前时间
    if (!_isEditing) {
      _timeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          setState(() => _date = DateTime.now());
        }
      });
    }

    _loadProjects();

    if (_isEditing) {
      _initEditData();
    } else {
      _selectedProjectId = widget.defaultProjectId;
      _loadDraft(); // 仅新增模式加载草稿
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await apiService.getProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _loadingProjects = false;
          // 如果没有选中项目且只有一个项目，默认选中
          if (_selectedProjectId == null && projects.length == 1) {
            _selectedProjectId = projects.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProjects = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载项目失败: $e')),
        );
      }
    }
  }

  void _initEditData() {
    final b = widget.editBill!;
    _amountCtrl.text = b.amount.toString();
    _billType = b.billType;
    _date = b.date;
    _noteCtrl.text = b.note ?? '';
    _selectedProjectId = b.projectId;

    // 支付方式
    final payMethod = b.payMethod ?? '现金';
    if (_payMethods.contains(payMethod)) {
      _selectedPayMethod = payMethod;
    } else {
      _selectedPayMethod = '其他';
      _customPayMethodCtrl.text = payMethod;
    }

    // 姓名直接设置
    _nameCtrl.text = b.name ?? '';

    // 工时设置
    if (b.durationHours != null && b.durationHours! > 0) {
      _durationCtrl.text = b.durationHours.toString();
    }
    if (b.hourlyRate != null) {
      _hourlyRateCtrl.text = b.hourlyRate.toString();
    }
  }

  @override
  void dispose() {
    // 页面关闭前，强制立即保存一次草稿(仅新增模式且未成功提交)
    if (!_isEditing && !_hasSubmitted) _saveDraft(immediate: true);

    _draftDebounce?.cancel();
    _timeUpdateTimer?.cancel(); // 取消时间定时器
    _amountCtrl.removeListener(_onFieldChange);
    _nameCtrl.removeListener(_onFieldChange);
    _noteCtrl.removeListener(_onFieldChange);
    _customPayMethodCtrl.removeListener(_onFieldChange);
    _durationCtrl.removeListener(_handleDurationChange);
    _hourlyRateCtrl.removeListener(_handleHourlyRateChange);

    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _customPayMethodCtrl.dispose();
    _durationCtrl.dispose();
    _hourlyRateCtrl.dispose();
    super.dispose();
  }

  void _onFieldChange() {
    if (_amountCtrl == _hourlyRateCtrl) return;
    if (_amountCtrl.text.isNotEmpty && !_isUpdatingAmountProgrammatically) {
      if (!_amountManuallyEdited) {
        setState(() {
          _amountManuallyEdited = true;
          _calcExplanation = null;
        });
      }
    }
    if (!_isEditing) _saveDraft();
  }

  void _handleDurationChange() {
    _maybeRecalculateAmount();
    if (!_isEditing) _saveDraft();
  }

  void _handleHourlyRateChange() {
    if (_hourlyRateCtrl.text.trim().isEmpty) {
      setState(() => _calcExplanation = null);
    } else {
      _maybeRecalculateAmount();
    }
    if (!_isEditing) _saveDraft();
  }

  // ==================== 草稿功能 (仅新增) ====================

  static const String _draftKey = 'bill_draft';

  Future<void> _saveDraft({bool immediate = false}) async {
    if (_isEditing) return; // 编辑模式不存草稿

    if (_draftDebounce?.isActive ?? false) _draftDebounce!.cancel();

    final doSave = () async {
      final prefs = await SharedPreferences.getInstance();
      final draftData = {
        'amount': _amountCtrl.text,
        'name': _nameCtrl.text,
        'note': _noteCtrl.text,
        'pay_method': _selectedPayMethod,
        'custom_pay_method': _customPayMethodCtrl.text,
        'hourly_rate': _hourlyRateCtrl.text,
        'duration': _durationCtrl.text,
        'bill_type': _billType,
        'date': _date.toUtc().toIso8601String(), // 保存为UTC时间
        'project_id': _selectedProjectId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_draftKey, jsonEncode(draftData));
    };

    if (immediate) {
      await doSave();
    } else {
      _draftDebounce = Timer(const Duration(milliseconds: 100), doSave);
    }
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString(_draftKey);
    if (draftString == null) return;

    try {
      final draft = jsonDecode(draftString) as Map<String, dynamic>;
      
      // 如果是从特定项目进入，且草稿属于其他项目，则不恢复
      final draftProjectId = draft['project_id'] as int?;
      if (widget.defaultProjectId != null && draftProjectId != widget.defaultProjectId) {
        // 草稿是其他项目的，清除并不恢复
        await _clearDraft();
        return;
      }
      
      final hasContent = (draft['amount']?.toString().isNotEmpty ?? false) ||
          (draft['note']?.toString().isNotEmpty ?? false) ||
          (draft['name']?.toString().isNotEmpty ?? false);

      if (!hasContent) return;

      if (!mounted) return;

      setState(() {
        _amountCtrl.text = draft['amount'] ?? '';
        _nameCtrl.text = draft['name'] ?? '';
        _noteCtrl.text = draft['note'] ?? '';
        _selectedPayMethod = draft['pay_method'] ?? '现金';
        _customPayMethodCtrl.text = draft['custom_pay_method'] ?? '';
        _hourlyRateCtrl.text = draft['hourly_rate'] ?? '';
        _durationCtrl.text = draft['duration']?.toString() ?? '';
        _billType = draft['bill_type'] ?? 'expense';
        if (draft['date'] != null) {
          _date = DateTime.parse(draft['date']).toLocal(); // 转换为本地时间显示
        }
        // 仅当没有指定默认项目时才从草稿恢复项目ID
        if (widget.defaultProjectId == null) {
          _selectedProjectId = draftProjectId;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已为您恢复上次未保存的内容'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _clearDraft();
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  // ==================== 逻辑方法 ====================

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
          _date.second,
        );
      });
      if (!_isEditing) _saveDraft();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _date.hour, minute: _date.minute),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          _date.year,
          _date.month,
          _date.day,
          picked.hour,
          picked.minute,
        );
      });
      if (!_isEditing) _saveDraft();
    }
  }

  void _maybeRecalculateAmount({bool force = false}) {
    final rate = double.tryParse(_hourlyRateCtrl.text.trim());
    if (rate == null || _duration <= 0) return;
    if (_amountManuallyEdited && !force) return;

    final computed = rate * _duration;
    final explanation =
        '${rate.toStringAsFixed(2)}元/h × ${_duration.toStringAsFixed(2)}h';

    _isUpdatingAmountProgrammatically = true;
    _amountCtrl.text = computed.toStringAsFixed(2);
    _isUpdatingAmountProgrammatically = false;
    _amountManuallyEdited = false;

    setState(() => _calcExplanation = explanation);
  }

  Future<void> _submit() async {
    if (_amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入金额')));
      return;
    }

    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择所属项目')));
      return;
    }

    final hourlyRate = double.tryParse(_hourlyRateCtrl.text.trim());

    // 获取姓名，如果为空则使用默认值
    final billName =
        _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : '未命名';

    // 分类固定为"人工"
    const category = '人工';

    // 获取支付方式
    final payMethod = _selectedPayMethod == '其他'
        ? (_customPayMethodCtrl.text.trim().isNotEmpty
            ? _customPayMethodCtrl.text.trim()
            : '其他')
        : _selectedPayMethod;

    String? note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    if (_calcExplanation != null) {
      final calcLine = '[语音推断] 基于 $_calcExplanation 计算';
      if (note == null) {
        note = calcLine;
      } else if (!note.contains(calcLine)) {
        note = '$note\n$calcLine';
      }
    }

    setState(() => _submitting = true);
    try {
      if (_isEditing) {
        // 更新逻辑
        final update = BillUpdate(
          amount: double.parse(_amountCtrl.text.trim()),
          billType: _billType,
          category: category,
          date: _date,
          note: note,
          name: billName,
          durationHours: _duration > 0 ? _duration : null,
          hourlyRate: hourlyRate,
          payMethod: payMethod,
          projectId: _selectedProjectId,
        );
        await apiService.updateBill(widget.editBill!.id!, update);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('更新成功')));
          Navigator.of(context).pop(true);
        }
      } else {
        // 创建逻辑
        // 确保项目ID不为空（前面已经验证过，这里是双重保障）
        assert(_selectedProjectId != null, '项目ID不能为空');

        final bill = Bill(
          amount: double.parse(_amountCtrl.text.trim()),
          billType: _billType,
          category: category,
          date: _date,
          note: note,
          name: billName,
          durationHours: _duration > 0 ? _duration : null,
          hourlyRate: hourlyRate,
          payMethod: payMethod,
          projectId: _selectedProjectId!, // 使用! 因为已经验证过
        );
        await apiService.createBill(bill);
        await _clearDraft();
        _hasSubmitted = true; // 标记已成功提交，防止dispose时重新保存草稿
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('保存成功')));
          Navigator.of(context).pop(true);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：${e.message}')));

        // 如果是认证错误，提示用户重新登录
        if (e.requiresReauth) {
          await apiService.clearToken();
          if (mounted) {
            await Provider.of<AuthProvider>(context, listen: false).logout();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatNumber(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑账单' : '记工时'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitting ? null : _submit,
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600), // 限制最大宽度，适配平板/电脑
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loadingProjects)
                const LinearProgressIndicator()
              else if (_projects.isEmpty)
                ListTile(
                  title: const Text('暂无项目，请先创建',
                      style: TextStyle(color: Colors.red)),
                  trailing: TextButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProjectListPage()));
                      _loadProjects(); // 返回后刷新
                    },
                    child: const Text('去创建'),
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: _selectedProjectId,
                  decoration: const InputDecoration(
                    labelText: '所属项目',
                    prefixIcon: Icon(Icons.folder),
                    helperText: '必须选择一个项目',
                  ),
                  items: _projects
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedProjectId = val);
                    if (!_isEditing) _saveDraft();
                  },
                ),
              const SizedBox(height: 16), // 增加间距

              // 收入/支出切换 - 现代风格 Tab 切换
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _billType = 'expense');
                          if (!_isEditing) _saveDraft();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _billType == 'expense'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _billType == 'expense'
                                ? [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '支出',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _billType == 'expense'
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _billType = 'income');
                          if (!_isEditing) _saveDraft();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _billType == 'income'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _billType == 'income'
                                ? [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '收入',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _billType == 'income'
                                    ? Colors.green
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 日期选择 - 更轻量的设计
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      controller: TextEditingController(text: df.format(_date)),
                      decoration: const InputDecoration(
                        labelText: '日期',
                        prefixIcon: Icon(Icons.calendar_today),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      controller: TextEditingController(text: tf.format(_date)),
                      decoration: const InputDecoration(
                        labelText: '时间',
                        prefixIcon: Icon(Icons.access_time),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // 1. 姓名 - 第一个
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: '姓名',
                  prefixIcon: Icon(Icons.person),
                  hintText: '输入工人姓名',
                ),
                onChanged: (v) {
                  if (!_isEditing) _saveDraft();
                },
              ),
              const SizedBox(height: 24),

              // 2. 时薪 - 第二个
              TextField(
                  controller: _hourlyRateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                      labelText: '时薪（元/小时）',
                      prefixIcon: Icon(Icons.payments_outlined))),
              const SizedBox(height: 24),

              // 3. 工时 - 第三个
              TextField(
                controller: _durationCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: '工时（小时）',
                  prefixIcon: Icon(Icons.timer),
                  hintText: '输入工时，如：8',
                ),
              ),
              const SizedBox(height: 24),

              // 4. 支付方式 - 第四个
              DropdownButtonFormField<String>(
                value: _selectedPayMethod,
                decoration: const InputDecoration(
                  labelText: '支付方式',
                  prefixIcon: Icon(Icons.payment),
                ),
                items: _payMethods
                    .map((method) => DropdownMenuItem(
                          value: method,
                          child: Text(method,
                              style: const TextStyle(fontSize: 16)),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedPayMethod = val ?? '现金');
                  if (!_isEditing) _saveDraft();
                },
              ),
              // 如果选择"其他"，显示自定义输入框
              if (_selectedPayMethod == '其他')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: _customPayMethodCtrl,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: '自定义支付方式',
                      hintText: '请输入支付方式',
                      prefixIcon: Icon(Icons.edit),
                    ),
                    onChanged: (v) {
                      if (!_isEditing) _saveDraft();
                    },
                  ),
                ),
              const SizedBox(height: 24),

              // 5. 金额 - 倒数第二个
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red), // 金额突出显示
                decoration: const InputDecoration(
                    labelText: '金额（元）', prefixIcon: Icon(Icons.attach_money)),
              ),
              if (_calcExplanation != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('基于 $_calcExplanation 自动计算',
                        style: const TextStyle(
                            color: Colors.green, fontSize: 14))),
              if (_duration > 0)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () => _maybeRecalculateAmount(force: true),
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('重算金额'))),
              const SizedBox(height: 24),

              // 6. 备注 - 最后一个
              TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                      labelText: '备注', prefixIcon: Icon(Icons.note))),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.save),
                  label: Text(_submitting ? '保存中...' : '保存'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
