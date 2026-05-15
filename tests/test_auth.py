"""
认证模块测试

测试用户注册、登录、获取当前用户等功能
"""
import pytest
from fastapi import status


# API 路径前缀
API_PREFIX = "/api/v1"


@pytest.mark.unit
class TestAuth:
    """认证功能单元测试"""
    
    def test_register_success(self, client):
        """测试成功注册"""
        response = client.post(
            f"{API_PREFIX}/auth/register",
            json={
                "username": "newuser",
                "email": "newuser@example.com",
                "password": "Test@123"
            }
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["username"] == "newuser"
        assert data["email"] == "newuser@example.com"
        assert "id" in data
        assert "hashed_password" not in data  # 不应返回密码
    
    def test_register_weak_password(self, client):
        """测试弱密码注册失败"""
        response = client.post(
            f"{API_PREFIX}/auth/register",
            json={
                "username": "weakuser",
                "email": "weak@example.com",
                "password": "123456"  # 弱密码
            }
        )
        # 密码太短会被 Pydantic 验证拦截返回 422
        assert response.status_code in [status.HTTP_400_BAD_REQUEST, status.HTTP_422_UNPROCESSABLE_ENTITY]
    
    def test_register_duplicate_username(self, client, test_user):
        """测试重复用户名注册失败"""
        response = client.post(
            f"{API_PREFIX}/auth/register",
            json={
                "username": test_user.username,
                "email": "another@example.com",
                "password": "Test@123"
            }
        )
        assert response.status_code == status.HTTP_409_CONFLICT
    
    def test_register_duplicate_email(self, client, test_user):
        """测试重复邮箱注册失败"""
        response = client.post(
            f"{API_PREFIX}/auth/register",
            json={
                "username": "anotheruser",
                "email": test_user.email,
                "password": "Test@123"
            }
        )
        assert response.status_code == status.HTTP_409_CONFLICT
    
    def test_login_success(self, client, test_user):
        """测试成功登录"""
        response = client.post(
            f"{API_PREFIX}/auth/login",
            json={
                "username": test_user.username,
                "password": "Test@123"
            }
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    def test_login_wrong_password(self, client, test_user):
        """测试错误密码登录失败"""
        response = client.post(
            f"{API_PREFIX}/auth/login",
            json={
                "username": test_user.username,
                "password": "wrongpassword"
            }
        )
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_login_nonexistent_user(self, client):
        """测试不存在用户登录失败"""
        response = client.post(
            f"{API_PREFIX}/auth/login",
            json={
                "username": "nonexistent",
                "password": "Test@123"
            }
        )
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_get_current_user(self, client, test_auth_headers):
        """测试获取当前用户"""
        response = client.get(
            f"{API_PREFIX}/auth/me",
            headers=test_auth_headers
        )
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "id" in data
        assert "username" in data
        assert "email" in data
    
    def test_get_current_user_without_token(self, client):
        """测试未认证获取用户失败"""
        response = client.get(f"{API_PREFIX}/auth/me")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_get_current_user_invalid_token(self, client):
        """测试无效令牌获取用户失败"""
        response = client.get(
            f"{API_PREFIX}/auth/me",
            headers={"Authorization": "Bearer invalid_token"}
        )
        assert response.status_code == status.HTTP_401_UNAUTHORIZED