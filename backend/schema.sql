-- Family Work Ledger Database Schema
-- MySQL/MariaDB Schema Definition

CREATE DATABASE IF NOT EXISTS family_ledger CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE family_ledger;

-- Expenses table
CREATE TABLE IF NOT EXISTS expenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL COMMENT '支出日期',
    receiver VARCHAR(100) NOT NULL COMMENT '收款对象',
    amount DECIMAL(10, 2) NOT NULL COMMENT '金额',
    project VARCHAR(100) NOT NULL COMMENT '项目名称',
    type VARCHAR(50) NOT NULL COMMENT '支出类型',
    pay_method VARCHAR(50) NOT NULL COMMENT '支付方式',
    note TEXT COMMENT '备注说明',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    INDEX idx_date (date),
    INDEX idx_receiver (receiver),
    INDEX idx_project (project),
    INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支出记录表';

-- Example data
INSERT INTO expenses (date, receiver, amount, project, type, pay_method, note) VALUES
    ('2025-01-15', '张三', 500.00, '办公用品', '采购', '微信', '购买文具'),
    ('2025-01-20', '李四', 1200.00, '设备维护', '维修', '支付宝', '电脑维修费'),
    ('2025-02-01', '王五', 300.00, '餐饮', '日常', '现金', '团队聚餐');
