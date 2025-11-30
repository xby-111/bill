from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db.database import engine
from db.init_db import create_tables
from routers import auth, bills

app = FastAPI(title="个人账单管理系统", version="1.0.0")

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 创建数据库表
create_tables()

# 注册路由
app.include_router(auth.router)
app.include_router(bills.router)

@app.get("/")
def read_root():
    return {"message": "欢迎使用个人账单管理系统"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}