"""
Pytest 配置文件

提供测试用的 fixtures
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, StaticPool
from sqlalchemy.orm import sessionmaker
from datetime import datetime, timezone

from db.database import Base, get_db
from models.user import User
from models.bill import Bill, BillHistory
from models.project import Project


# 使用共享内存数据库进行测试（StaticPool 确保连接共享）
TEST_DATABASE_URL = "sqlite:///:memory:"

test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,  # 使用静态连接池确保所有连接共享同一个内存数据库
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


@pytest.fixture(scope="function")
def db():
    """创建测试数据库会话"""
    # 在测试引擎上创建所有表
    Base.metadata.create_all(bind=test_engine)
    
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(scope="function")
def client(db):
    """创建测试客户端"""
    # 延迟导入 app 避免在导入时触发数据库初始化
    from main import app
    from utils.rate_limit import rate_limiter
    
    # 清除速率限制器状态
    rate_limiter._requests.clear()
    
    def override_get_db():
        yield db
    
    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as test_client:
        yield test_client
    
    app.dependency_overrides.clear()
    # 测试后再次清除
    rate_limiter._requests.clear()


@pytest.fixture
def test_user(db):
    """创建测试用户"""
    from services.auth_service import get_password_hash
    
    user = User(
        username="testuser",
        email="test@example.com",
        hashed_password=get_password_hash("Test@123")
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def test_auth_headers(client, test_user):
    """获取认证头"""
    response = client.post(
        "/api/v1/auth/login",
        json={
            "username": test_user.username,
            "password": "Test@123"
        }
    )
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def test_project(db, test_user):
    """创建测试项目"""
    project = Project(
        name="测试项目",
        description="用于单元测试的项目",
        user_id=test_user.id
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@pytest.fixture
def sample_bill_data(test_projecttest_project):
    """示例账单数据（用于 API 请求）"""
    return {
        "name": "张师傅工作",
        "amount": 100.50,
        "bill_type": "expense",
        "category": "人工",
        "date": datetime.now(timezone.utc).isoformat(),
        "duration_hours": 8.0,
        "hourly_rate": 12.56,
        "pay_method": "现金",
        "note": "测试账单",
        "project_id": test_project.id
    }


@pytest.fixture
def sample_bill(db, test_user, test_project):
    """创建示例账单（直接插入数据库）"""
    bill = Bill(
        name="张师傅工作",
        amount=100.50,
        bill_type="expense",
        category="人工",
        date=datetime.now(timezone.utc),  # 使用 datetime 对象，不是字符串
        duration_hours=8.0,
        hourly_rate=12.56,
        pay_method="现金",
        note="测试账单",
        user_id=test_user.id,
        project_id=test_project.id
    )
    db.add(bill)
    db.commit()
    db.refresh(bill)
    return bill