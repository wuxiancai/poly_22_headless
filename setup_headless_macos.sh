#!/bin/bash

# macOS无头环境一键部署脚本
# 用于测试Polymarket自动交易程序

echo "🚀 开始在macOS上部署无头环境..."

# 检查是否安装了Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ 未检测到Homebrew，正在安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrew已安装"
fi

# 更新Homebrew
echo "📦 更新Homebrew..."
brew update

# 安装Chrome浏览器（如果未安装）
if ! brew list --cask google-chrome &> /dev/null; then
    echo "🌐 安装Google Chrome..."
    brew install --cask google-chrome
else
    echo "✅ Google Chrome已安装"
fi

# 安装ChromeDriver
echo "🔧 安装ChromeDriver..."
brew install chromedriver

# 验证ChromeDriver安装
if command -v chromedriver &> /dev/null; then
    echo "✅ ChromeDriver安装成功: $(chromedriver --version)"
else
    echo "❌ ChromeDriver安装失败"
    exit 1
fi

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "🐍 安装Python3..."
    brew install python3
else
    echo "✅ Python3已安装: $(python3 --version)"
fi

# 检查pip
if ! command -v pip3 &> /dev/null; then
    echo "📦 安装pip3..."
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py
    rm get-pip.py
else
    echo "✅ pip3已安装"
fi

# 安装Python依赖
echo "📚 安装Python依赖包..."
pip3 install selenium webdriver-manager flask requests beautifulsoup4 lxml

# 创建测试脚本
echo "📝 创建无头浏览器测试脚本..."
cat > test_headless.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

def test_headless_browser():
    """测试无头浏览器环境"""
    print("🧪 测试无头浏览器环境...")
    
    # 配置Chrome选项
    chrome_options = Options()
    chrome_options.add_argument('--headless')  # 无头模式
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument('--disable-dev-shm-usage')
    chrome_options.add_argument('--disable-gpu')
    chrome_options.add_argument('--window-size=1920,1080')
    chrome_options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')
    
    try:
        # 创建WebDriver实例
        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=chrome_options)
        
        # 测试访问网页
        print("🌐 访问测试网页...")
        driver.get('https://www.google.com')
        
        # 获取页面标题
        title = driver.title
        print(f"✅ 页面标题: {title}")
        
        # 测试本地服务器
        print("🏠 测试本地服务器连接...")
        driver.get('http://localhost:5000')
        time.sleep(2)
        
        local_title = driver.title
        print(f"✅ 本地页面标题: {local_title}")
        
        driver.quit()
        print("✅ 无头浏览器测试成功！")
        return True
        
    except Exception as e:
        print(f"❌ 无头浏览器测试失败: {str(e)}")
        return False

if __name__ == '__main__':
    test_headless_browser()
EOF

# 设置执行权限
chmod +x test_headless.py

# 创建启动脚本
echo "🚀 创建无头模式启动脚本..."
cat > start_headless_trading.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import time

def start_headless_trading():
    """启动无头模式交易程序"""
    print("🤖 启动无头模式Polymarket自动交易程序...")
    
    # 设置环境变量启用无头模式
    os.environ['HEADLESS_MODE'] = '1'
    os.environ['DISPLAY'] = ':99'  # 虚拟显示器
    
    try:
        # 启动交易程序
        print("🚀 启动crypto_trader.py...")
        process = subprocess.Popen(
            [sys.executable, 'crypto_trader.py'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        print("✅ 程序已在无头模式下启动")
        print("📊 Web界面地址: http://localhost:5000")
        print("⏹️  按Ctrl+C停止程序")
        
        # 等待程序运行
        try:
            process.wait()
        except KeyboardInterrupt:
            print("\n🛑 正在停止程序...")
            process.terminate()
            process.wait()
            print("✅ 程序已停止")
            
    except Exception as e:
        print(f"❌ 启动失败: {str(e)}")

if __name__ == '__main__':
    start_headless_trading()
EOF

# 设置执行权限
chmod +x start_headless_trading.py

echo ""
echo "🎉 macOS无头环境部署完成！"
echo ""
echo "📋 使用说明:"
echo "1. 测试无头浏览器: python3 test_headless.py"
echo "2. 启动无头交易程序: python3 start_headless_trading.py"
echo "3. 或者直接运行: python crypto_trader.py"
echo ""
echo "🌐 Web界面地址: http://localhost:5000"
echo "📝 在Web界面中配置交易仓位后，程序将自动进行交易监控"
echo ""
echo "⚠️  注意事项:"
echo "- 确保网络连接正常"
echo "- 首次运行可能需要下载ChromeDriver"
echo "- 交易前请仔细检查配置参数"
echo ""