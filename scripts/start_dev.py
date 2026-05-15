#!/usr/bin/env python
"""
开发环境启动脚本

自动激活虚拟环境、检查依赖、启动服务
"""
import os
import sys
import subprocess
import platform

def check_python():
    """检查 Python 版本"""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 10):
        print(f"❌ Python 版本过低: {sys.version}")
        print("   需要 Python 3.10+")
        sys.exit(1)
    print(f"✓ Python {version.major}.{version.minor}.{version.micro}")

def check_venv():
    """检查虚拟环境"""
    venv_path = os.path.join(os.path.dirname(__file__), "venv")
    if not os.path.exists(venv_path):
        print("❌ 未找到虚拟环境 venv/")
        print("   请运行: python -m venv venv")
        sys.exit(1)
    
    # 检查是否在虚拟环境中
    if sys.prefix == sys.base_prefix:
        print("⚠️  未激活虚拟环境")
        if platform.system() == "Windows":
            print("   请运行: .\\venv\\Scripts\\activate")
        else:
            print("   请运行: source venv/bin/activate")
        return False
    
    print("✓ 虚拟环境已激活")
    return True

def check_dependencies():
    """检查依赖是否安装"""
    try:
        import fastapi
        import uvicorn
        import sqlalchemy
        print("✓ 核心依赖已安装")
        return True
    except ImportError as e:
        print(f"❌ 缺少依赖: {e.name}")
        print("   请运行: pip install -r requirements.txt")
        return False

def check_env():
    """检查环境变量配置"""
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if not os.path.exists(env_path):
        example_path = os.path.join(os.path.dirname(__file__), "config", "env", ".env.example")
        print("⚠️  未找到 .env 配置文件")
        print(f"   请复制示例: copy {example_path} .env")
        return False
    print("✓ .env 配置文件存在")
    return True

def start_server(host="0.0.0.0", port=8000, reload=True):
    """启动开发服务器"""
    print("\n" + "="*50)
    print("🚀 启动开发服务器...")
    print("="*50)
    print(f"   地址: http://{host}:{port}")
    print(f"   文档: http://{host}:{port}/api/docs")
    print(f"   热重载: {'启用' if reload else '禁用'}")
    print("="*50 + "\n")
    
    import uvicorn
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=reload,
        log_level="info",
    )

def main():
    print("\n" + "="*50)
    print("  家庭工时记账系统 - 开发环境启动")
    print("="*50 + "\n")
    
    check_python()
    
    if not check_venv():
        sys.exit(1)
    
    if not check_dependencies():
        sys.exit(1)
    
    check_env()
    
    # 解析命令行参数
    host = "0.0.0.0"
    port = 8000
    reload = True
    
    for arg in sys.argv[1:]:
        if arg.startswith("--host="):
            host = arg.split("=")[1]
        elif arg.startswith("--port="):
            port = int(arg.split("=")[1])
        elif arg == "--no-reload":
            reload = False
    
    start_server(host, port, reload)

if __name__ == "__main__":
    main()
