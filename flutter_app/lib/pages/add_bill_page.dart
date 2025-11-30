import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/bill.dart';
import '../services/api_service.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key});

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _amountCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: '人工');
  final _noteCtrl = TextEditingController();
  final _payMethodCtrl = TextEditingController(text: '现金');
  final _hourlyRateCtrl = TextEditingController();
  final _speech = stt.SpeechToText();

  DateTime _date = DateTime.now();
  String _billType = 'expense';
  String? _selectedWorker;
  String? _customWorker;
  double _duration = 0;
  bool _submitting = false;
  String _speechStatus = '未开启';
  bool _amountManuallyEdited = false;
  bool _isUpdatingAmountProgrammatically = false;
  String? _calcExplanation;

  final _workers = ['张师傅', '李阿姨', '王叔叔'];

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_handleAmountInputChange);
    _hourlyRateCtrl.addListener(_handleHourlyRateChange);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_handleAmountInputChange);
    _hourlyRateCtrl.removeListener(_handleHourlyRateChange);
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    _payMethodCtrl.dispose();
    _hourlyRateCtrl.dispose();
    super.dispose();
  }

  void _handleAmountInputChange() {
    if (_isUpdatingAmountProgrammatically) return;
    if (!_amountManuallyEdited && _amountCtrl.text.isNotEmpty) {
      setState(() {
        _amountManuallyEdited = true;
        _calcExplanation = null;
      });
    }
  }

  void _handleHourlyRateChange() {
    if (_hourlyRateCtrl.text.trim().isEmpty) {
      setState(() => _calcExplanation = null);
      return;
    }
    _maybeRecalculateAmount();
  }

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
    }
  }

  void _setDuration(double value) {
    setState(() {
      _duration = value;
      if (value == 0) _calcExplanation = null;
    });
    _maybeRecalculateAmount();
  }

  void _incDuration(double delta) {
    setState(() {
      _duration = (_duration + delta).clamp(0, 24);
      if (_duration == 0) _calcExplanation = null;
    });
    _maybeRecalculateAmount();
  }

  void _maybeRecalculateAmount({bool force = false}) {
    final rate = double.tryParse(_hourlyRateCtrl.text.trim());
    if (rate == null || _duration <= 0) return;
    if (_amountManuallyEdited && !force) return;

    final computed = rate * _duration;
    final explanation = '${rate.toStringAsFixed(2)}元/h × ${_duration.toStringAsFixed(2)}h';

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

    final hourlyRate = double.tryParse(_hourlyRateCtrl.text.trim());
    final worker = _customWorker?.trim().isNotEmpty == true
        ? _customWorker!.trim()
        : _selectedWorker;

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
      final bill = Bill(
        amount: double.parse(_amountCtrl.text.trim()),
        billType: _billType,
        category: _categoryCtrl.text.trim(),
        date: _date,
        note: note,
        worker: worker,
        durationHours: _duration > 0 ? _duration : null,
        hourlyRate: hourlyRate,
        payMethod: _payMethodCtrl.text.trim().isEmpty
            ? null
            : _payMethodCtrl.text.trim(),
      );
      await apiService.createBill(bill);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存成功')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) => setState(() => _speechStatus = status),
      onError: (err) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('语音错误：${err.errorMsg}')),
      ),
    );
    if (!available) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('语音识别不可用')));
      return;
    }
    _speech.listen(onResult: (result) {
      if (result.finalResult) _handleSpeech(result.recognizedWords);
    });
  }

  void _stopSpeech() {
    _speech.stop();
    setState(() => _speechStatus = '停止');
  }

  void _handleSpeech(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    final result = _parseSpeechText(cleaned);

    setState(() {
      if (result.worker != null) {
        _selectedWorker = result.worker;
        _customWorker = null;
      }
      if (result.durationHours != null) {
        _duration = result.durationHours!.clamp(0, 24);
      }
      if (result.startDateTime != null) {
        _date = result.startDateTime!;
      }
    });

    if (result.hourlyRate != null) {
      _hourlyRateCtrl.text = _formatNumber(result.hourlyRate!);
    }

    if (result.amount != null) {
      _isUpdatingAmountProgrammatically = true;
      _amountCtrl.text = _formatNumber(result.amount!);
      _isUpdatingAmountProgrammatically = false;
      _amountManuallyEdited = false;
      setState(() => _calcExplanation = null);
    } else if (result.hourlyRate != null && result.durationHours != null) {
      _maybeRecalculateAmount(force: true);
    }

    _appendSpeechNote(cleaned);
  }

  void _appendSpeechNote(String rawText) {
    final voiceLine = '[语音原文] $rawText';
    final existing = _noteCtrl.text.trim();
    if (existing.contains(voiceLine)) return;
    final updated = [existing, voiceLine].where((e) => e.isNotEmpty).join('\n');
    _noteCtrl.text = updated;
  }

  _SpeechParseResult _parseSpeechText(String raw) {
    final normalized = raw.replaceAll('：', ':');
    final worker = _detectWorker(normalized);
    final duration = _detectDuration(normalized, currentDuration: _duration);
    final timeResult = _detectStartTime(normalized);
    final rateResult = _detectHourlyRate(normalized);
    final amount = _detectAmount(
      normalized,
      exclude: rateResult?.matchedRaw,
    );

    return _SpeechParseResult(
      worker: worker,
      durationHours: duration,
      hourlyRate: rateResult?.value,
      amount: amount,
      startDateTime: timeResult,
    );
  }

  String? _detectWorker(String text) {
    for (final w in _workers) {
      if (text.contains(w)) return w;
    }
    final fallback = RegExp(r'([\u4e00-\u9fa5]{1,4})(师傅|阿姨|叔叔|大哥|大姐|老师)');
    final match = fallback.firstMatch(text);
    if (match != null) {
      return match.group(0);
    }
    return null;
  }

  double? _detectDuration(String text, {double currentDuration = 0}) {
    if (text.contains('半工') || text.contains('半天')) return 4;
    if (text.contains('大工') || text.contains('整天')) return 8;

    final complex = RegExp(r'(\d+)(?:个)?半小?时').firstMatch(text);
    if (complex != null) {
      return double.parse(complex.group(1)!) + 0.5;
    }

    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:个)?小?时');
    final match = regex.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }

    if (text.contains('加班')) {
      final extraMatch = RegExp(r'加班(?:了)?(\d+(?:\.\d+)?)?').firstMatch(text);
      if (extraMatch != null && extraMatch.group(1) != null) {
        final inc = double.tryParse(extraMatch.group(1)!);
        if (inc != null) return currentDuration + inc;
      }
      return (currentDuration + 1).clamp(0, 24);
    }

    return null;
  }

  _RateParseResult? _detectHourlyRate(String text) {
    final patterns = [
      RegExp(r'每(?:个)?(?:小?时|小时|工时)[^\d]{0,4}(\d+(?:\.\d+)?)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:块钱|块|元)?\s*(?:一个|每个|每)?(?:小?时|小时|工时)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = double.tryParse(match.group(1)!);
        if (value != null) {
          return _RateParseResult(value: value, matchedRaw: match.group(0)!);
        }
      }
    }
    return null;
  }

  double? _detectAmount(String text, {String? exclude}) {
    var source = text;
    if (exclude != null) {
      source = source.replaceFirst(exclude, '');
    }
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块钱|块|元|人民币)');
    final match = regex.firstMatch(source);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  DateTime? _detectStartTime(String text) {
    final base = _date;
    final generic = RegExp(
      r'(上午|早上|清晨|中午|下午|傍晚|晚上|凌晨)?\s*(\d{1,2})(?:[::](\d{1,2}))',
    );
    final dotMatch = generic.firstMatch(text);
    if (dotMatch != null) {
      final qualifier = dotMatch.group(1);
      final hour = int.parse(dotMatch.group(2)!);
      final minute = int.parse(dotMatch.group(3)!);
      final mappedHour = _mapHourWithQualifier(hour, qualifier);
      return DateTime(base.year, base.month, base.day, mappedHour, minute);
    }

    final hourRegex = RegExp(
      r'(上午|早上|清晨|中午|下午|傍晚|晚上|凌晨)?\s*(\d{1,2})点(半)?',
    );
    final hourMatch = hourRegex.firstMatch(text);
    if (hourMatch != null) {
      final qualifier = hourMatch.group(1);
      final hour = int.parse(hourMatch.group(2)!);
      final minute = hourMatch.group(3) != null ? 30 : 0;
      final mappedHour = _mapHourWithQualifier(hour, qualifier);
      return DateTime(base.year, base.month, base.day, mappedHour, minute);
    }

    return null;
  }

  int _mapHourWithQualifier(int hour, String? qualifier) {
    var h = hour % 24;
    final q = qualifier ?? '';
    if (q.contains('下午') || q.contains('晚上') || q.contains('傍晚')) {
      if (h < 12) h += 12;
    } else if (q.contains('中午')) {
      if (h >= 1 && h <= 5) h += 12;
    } else if (q.contains('凌晨')) {
      if (h == 12) h = 0;
    }
    return h;
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('记工时'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitting ? null : _submit,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ToggleButtons(
            isSelected: [_billType == 'expense', _billType == 'income'],
            onPressed: (index) {
              setState(() => _billType = index == 0 ? 'expense' : 'income');
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('支出'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('收入'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金额（元）',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          if (_calcExplanation != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '基于 $_calcExplanation 自动计算，可手动修改',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (_duration > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: double.tryParse(_hourlyRateCtrl.text.trim()) != null
                    ? () => _maybeRecalculateAmount(force: true)
                    : null,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('根据时薪重算金额'),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
              labelText: '分类（如人工/材料/餐饮）',
              prefixIcon: Icon(Icons.category),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text('日期：${df.format(_date)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          ListTile(
            title: Text('时间：${tf.format(_date)}'),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          const Divider(),
          const Text('工时'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('半工 (4h)'),
                onPressed: () => _setDuration(4),
              ),
              ActionChip(
                label: const Text('大工 (8h)'),
                onPressed: () => _setDuration(8),
              ),
              ActionChip(
                label: const Text('加班 (+1h)'),
                onPressed: () => _incDuration(1),
              ),
              ActionChip(
                label: const Text('清零'),
                onPressed: () => _setDuration(0),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _duration > 0 ? '当前工时：$_duration 小时' : '未设置工时',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hourlyRateCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '时薪（元/小时）',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const Divider(),
          const Text('工人'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedWorker,
            items: [
              const DropdownMenuItem(value: null, child: Text('未选择')),
              ..._workers
                  .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                  .toList(),
            ],
            onChanged: (val) {
              setState(() {
                _selectedWorker = val;
                if (val != null) _customWorker = null;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: '自定义工人姓名',
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (value) {
              setState(() {
                _customWorker = value;
                if (value.isNotEmpty) _selectedWorker = null;
              });
            },
          ),
          const Divider(),
          TextField(
            controller: _payMethodCtrl,
            decoration: const InputDecoration(
              labelText: '支付方式（现金/微信/支付宝/银行）',
              prefixIcon: Icon(Icons.payment),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注',
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_submitting ? '保存中...' : '保存'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const Text('语音助手'),
          const SizedBox(height: 8),
          GestureDetector(
            onLongPressStart: (_) => _startSpeech(),
            onLongPressEnd: (_) => _stopSpeech(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '按住说话（状态：$_speechStatus）\n示例："张师傅今天大工，8小时"',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechParseResult {
  final String? worker;
  final double? durationHours;
  final double? hourlyRate;
  final double? amount;
  final DateTime? startDateTime;

  const _SpeechParseResult({
    this.worker,
    this.durationHours,
    this.hourlyRate,
    this.amount,
    this.startDateTime,
  });
}

class _RateParseResult {
  final double value;
  final String matchedRaw;

  const _RateParseResult({
    required this.value,
    required this.matchedRaw,
  });
}
