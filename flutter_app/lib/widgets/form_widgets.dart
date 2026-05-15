/// 通用表单组件
/// 
/// 提供可复用的表单输入控件
library;

import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// 工时选择器
/// 
/// 支持快捷按钮和自定义工时
class DurationPicker extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double? hourlyRate;
  final String? calculatedAmount;

  const DurationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.hourlyRate,
    this.calculatedAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('工时'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: Text('半工 (${AppConfig.halfDayHours.toInt()}h)'),
              onPressed: () => onChanged(AppConfig.halfDayHours),
            ),
            ActionChip(
              label: Text('大工 (${AppConfig.fullDayHours.toInt()}h)'),
              onPressed: () => onChanged(AppConfig.fullDayHours),
            ),
            ActionChip(
              label: const Text('加班 (+1h)'),
              onPressed: () => onChanged((value + 1).clamp(0, 24)),
            ),
            ActionChip(
              label: const Text('清零'),
              onPressed: () => onChanged(0),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            value > 0 ? '当前工时：$value 小时' : '未设置工时',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

/// 金额输入框
/// 
/// 带有自动计算提示
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String? calculationHint;
  final VoidCallback? onRecalculate;
  final bool canRecalculate;

  const AmountField({
    super.key,
    required this.controller,
    this.calculationHint,
    this.onRecalculate,
    this.canRecalculate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '金额（元）',
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
        if (calculationHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '基于 $calculationHint 自动计算，可手动修改',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (canRecalculate && onRecalculate != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRecalculate,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('根据时薪重算金额'),
            ),
          ),
      ],
    );
  }
}

/// 日期时间选择器
class DateTimePicker extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const DateTimePicker({
    super.key,
    required this.value,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text('日期：${_formatDate(value)}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onDateChanged(DateTime(
                picked.year,
                picked.month,
                picked.day,
                value.hour,
                value.minute,
              ));
            }
          },
        ),
        ListTile(
          title: Text('时间：${_formatTime(value)}'),
          trailing: const Icon(Icons.access_time),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
            );
            if (picked != null) {
              onTimeChanged(picked);
            }
          },
        ),
      ],
    );
  }
}

/// 账单类型切换按钮
class BillTypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const BillTypeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: [value == 'expense', value == 'income'],
      onPressed: (index) => onChanged(index == 0 ? 'expense' : 'income'),
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
    );
  }
}

/// 智能录入面板
/// 
/// 包含语音和拍照识别按钮
class SmartInputPanel extends StatelessWidget {
  final bool isRecognizing;
  final String speechStatus;
  final VoidCallback onCameraPressed;
  final VoidCallback onSpeechStart;
  final VoidCallback onSpeechEnd;

  const SmartInputPanel({
    super.key,
    required this.isRecognizing,
    required this.speechStatus,
    required this.onCameraPressed,
    required this.onSpeechStart,
    required this.onSpeechEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('智能录入'),
        const SizedBox(height: 8),
        Row(
          children: [
            // 拍单据按钮
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: isRecognizing ? null : onCameraPressed,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRecognizing
                        ? Colors.grey.shade200
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      isRecognizing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt,
                              color: Colors.orange, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        isRecognizing ? '识别中' : '拍单据',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRecognizing
                              ? Colors.grey
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 语音按钮
            Expanded(
              flex: 3,
              child: GestureDetector(
                onLongPressStart: (_) => onSpeechStart(),
                onLongPressEnd: (_) => onSpeechEnd(),
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
                          '按住说话（状态：$speechStatus）\n示例："张师傅大工8小时，30块一小时"',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
