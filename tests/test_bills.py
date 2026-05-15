"""
账单模块测试

测试账单的 CRUD、统计、历史等功能
"""
import pytest
from fastapi import status
from datetime import datetime, timezone
from models.bill import Bill


# API 路径前缀
API_PREFIX = "/api/v1"


@pytest.mark.unit
class TestBills:
    """账单功能单元测试"""
    
    def test_create_bill_success(self, client, test_auth_headers, sample_bill_data):
        """测试成功创建账单"""
        response = client.post(
            f"{API_PREFIX}/bills/",
            json=sample_bill_data,
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["amount"] == sample_bill_data["amount"]
        assert data["bill_type"] == sample_bill_data["bill_type"]
        assert data["category"] == sample_bill_data["category"]
        assert "id" in data
    
    def test_get_bills_empty(self, client, test_auth_headers):
        """测试获取空账单列表"""
        response = client.get(
            f"{API_PREFIX}/bills/",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        assert response.json() == []
    
    def test_get_bills(self, client, test_auth_headers, sample_bill):
        """测试获取账单列表"""
        response = client.get(
            f"{API_PREFIX}/bills/",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert len(data) == 1
        assert data[0]["id"] == sample_bill.id
    
    def test_get_bill_by_id(self, client, test_auth_headers, sample_bill):
        """测试获取单个账单"""
        response = client.get(
            f"{API_PREFIX}/bills/{sample_bill.id}",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["id"] == sample_bill.id
        assert data["amount"] == sample_bill.amount
    
    def test_get_bill_not_found(self, client, test_auth_headers):
        """测试获取不存在的账单"""
        response = client.get(
            f"{API_PREFIX}/bills/99999",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_404_NOT_FOUND
    
    def test_update_bill(self, client, test_auth_headers, sample_bill):
        """测试更新账单"""
        update_data = {
            "amount": 200.00,
            "note": "更新后的备注"
        }
        response = client.put(
            f"{API_PREFIX}/bills/{sample_bill.id}",
            json=update_data,
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["amount"] == update_data["amount"]
        assert data["note"] == update_data["note"]
    
    def test_delete_bill(self, client, test_auth_headers, sample_bill):
        """测试删除账单"""
        response = client.delete(
            f"{API_PREFIX}/bills/{sample_bill.id}",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        
        # 验证账单已被删除
        response = client.get(
            f"{API_PREFIX}/bills/{sample_bill.id}",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_404_NOT_FOUND
    
    def test_get_monthly_statistics(self, client, test_auth_headers, sample_bill):
        """测试月度统计"""
        month_str = datetime.now(timezone.utc).strftime("%Y-%m")
        response = client.get(
            f"{API_PREFIX}/bills/statistics/monthly?month={month_str}",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["month"] == month_str
        assert data["total_expense"] > 0
    
    def test_get_category_statistics(self, client, test_auth_headers, sample_bill):
        """测试分类统计"""
        response = client.get(
            f"{API_PREFIX}/bills/statistics/category",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert len(data) > 0
        assert data[0]["category"] == sample_bill.category
    
    def test_get_name_statistics(self, client, test_auth_headers, sample_bill):
        """测试名称统计"""
        response = client.get(
            f"{API_PREFIX}/bills/statistics/name",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert len(data) > 0
        assert data[0]["name"] == sample_bill.name
    
    def test_get_bill_history(self, client, test_auth_headers, sample_bill):
        """测试获取账单历史"""
        # 先更新账单以创建历史记录
        client.put(
            f"{API_PREFIX}/bills/{sample_bill.id}",
            json={"amount": 300.00},
            headers=test_auth_headers
        )
        
        response = client.get(
            f"{API_PREFIX}/bills/{sample_bill.id}/history",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert len(data) > 0
        assert data[0]["operation_type"] == "UPDATE"
    
    def test_restore_bill_version(self, client, test_auth_headers, sample_bill):
        """测试恢复账单版本"""
        # 先更新账单
        client.put(
            f"{API_PREFIX}/bills/{sample_bill.id}",
            json={"amount": 300.00},
            headers=test_auth_headers
        )
        
        # 获取历史记录
        history_response = client.get(
            f"{API_PREFIX}/bills/{sample_bill.id}/history",
            headers=test_auth_headers
        )
        history_id = history_response.json()[0]["id"]
        
        # 恢复版本
        response = client.post(
            f"{API_PREFIX}/bills/history/{history_id}/restore",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["amount"] == sample_bill.amount  # 应该恢复到原始金额
    
    def test_unauthorized_access(self, client, sample_bill):
        """测试未授权访问"""
        response = client.get(f"{API_PREFIX}/bills/{sample_bill.id}")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_access_other_user_bill(self, client, db):
        """测试访问其他用户的账单"""
        # 创建两个用户
        from services.auth_service import create_user
        from schemas.user import UserCreate
        
        user1 = create_user(
            db,
            UserCreate(username="user1", email="user1@test.com", password="Test@123")
        )
        user2 = create_user(
            db,
            UserCreate(username="user2", email="user2@test.com", password="Test@123")
        )
        
        # user1 创建账单
        bill = Bill(
            name="测试账单",
            amount=100.0,
            bill_type="expense",
            category="测试",
            date=datetime.now(timezone.utc),
            user_id=user1.id
        )
        db.add(bill)
        db.commit()
        
        # user2 登录
        login_response = client.post(
            f"{API_PREFIX}/auth/login",
            json={"username": "user2", "password": "Test@123"}
        )
        token = login_response.json()["access_token"]
        
        # user2 尝试访问 user1 的账单
        response = client.get(
            f"{API_PREFIX}/bills/{bill.id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == status.HTTP_404_NOT_FOUND