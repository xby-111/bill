# Family Work Ledger (Flutter + AGPL)

简洁账本风、跨平台（iOS/Android）、支持本地SQLite与云端MySQL（阿里云 Lighthouse）同步的开源记账应用。

## 特性
- 表格型主界面（类似 Excel，支持横向滚动多列）
- 记录字段：日期 / 对象 / 金额 / 项目 / 类型 / 支付方式 / 备注
- 搜索与筛选（对象/项目/日期范围/类型/支付方式）
- 统计汇总（项目/时间段）
- 导出 CSV
- 本地 SQLite（离线可用）
- 云端同步接口（Lighthouse + Flask + MySQL）
- 智能录入（自动补全/模板/语音）

## 快速开始（Flutter）
```bash
flutter pub get
flutter run
```

## 后端（Lighthouse + Flask + MySQL）
```bash
pip install -r backend/requirements.txt
python backend/app.py
```

## License
本项目基于 AGPL v3.0 开源发布。
Original Author: xby-111
