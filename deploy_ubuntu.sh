#!/bin/bash

# Polymarket自动交易系统 - Ubuntu Server 22.04 一键部署脚本
# 包含Python虚拟环境、Chrome/Chromium、系统依赖安装
# 适配crypto_trader.py项目

set -e  # 遇到错误立即退出

echo "🚀 开始部署Polymarket自动交易系统到 Ubuntu Server 22.04..."

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
    echo "❌ 请不要使用root用户运行此脚本"
    exit 1
fi

# 获取当前用户和目录
CURRENT_USER=$(whoami)
PROJECT_DIR=$(pwd)
VENV_DIR="$PROJECT_DIR/venv"

echo "📍 当前用户: $CURRENT_USER"
echo "📍 项目目录: $PROJECT_DIR"

# 1. 系统更新和基础依赖安装
echo "📦 更新系统并安装基础依赖..."
sudo apt update -y
sudo apt upgrade -y

# 安装Python3和pip
sudo apt install -y python3 python3-pip python3-venv python3-dev

# 安装系统依赖（Chrome/Chromium需要）
sudo apt install -y \
    wget \
    curl \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    xvfb \
    libgconf-2-4 \
    libxi6 \
    libxcursor1 \
    libxss1 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libgtk-3-0 \
    libgbm-dev \
    libnss3-dev \
    libxss-dev

echo "✅ 系统基础依赖安装完成"

# 2. 安装Chrome浏览器
echo "🌐 安装Google Chrome..."

# 添加Google Chrome官方源
if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]; then
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    sudo apt update -y
fi

# 安装Chrome stable版本
sudo apt install -y google-chrome-stable

# 验证Chrome安装
if command -v google-chrome &> /dev/null; then
    CHROME_VERSION=$(google-chrome --version)
    echo "✅ Chrome安装成功: $CHROME_VERSION"
else
    echo "❌ Chrome安装失败，尝试安装Chromium..."
    sudo apt install -y chromium-browser
    if command -v chromium-browser &> /dev/null; then
        echo "✅ Chromium安装成功"
    else
        echo "❌ 浏览器安装失败"
        exit 1
    fi
fi

# 3. 创建Python虚拟环境
echo "🐍 创建Python虚拟环境..."

if [ -d "$VENV_DIR" ]; then
    echo "⚠️  虚拟环境已存在，删除重建..."
    rm -rf "$VENV_DIR"
fi

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# 升级pip
pip install --upgrade pip setuptools wheel

echo "✅ Python虚拟环境创建完成"

# 4. 安装Python依赖
echo "📚 安装Python依赖包..."

# 检查requirements.txt是否存在
if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
    echo "📝 创建requirements.txt文件..."
    cat > "$PROJECT_DIR/requirements.txt" << EOF
flask>=2.2
selenium>=4.12
webdriver-manager>=3.8
requests>=2.28
psutil>=5.9
websocket-client>=1.6
EOF
fi

pip install -r "$PROJECT_DIR/requirements.txt"

echo "✅ Python依赖安装完成"

# 5. 配置Chrome Driver和启动脚本
echo "🚗 配置Chrome Driver和启动脚本..."

# 确保start_chrome_ubuntu.sh脚本存在且可执行
if [ ! -f "$PROJECT_DIR/start_chrome_ubuntu.sh" ]; then
    echo "📝 创建start_chrome_ubuntu.sh脚本..."
    cat > "$PROJECT_DIR/start_chrome_ubuntu.sh" << 'EOF'
#!/bin/bash
# Ubuntu Chrome启动脚本
echo "启动Chrome浏览器（无头模式）..."
google-chrome --headless --no-sandbox --disable-dev-shm-usage --remote-debugging-port=9222 &
echo "Chrome已启动，调试端口：9222"
EOF
    chmod +x "$PROJECT_DIR/start_chrome_ubuntu.sh"
fi

chmod +x "$PROJECT_DIR/start_chrome_ubuntu.sh"

# 测试Chrome启动脚本
echo "🧪 测试Chrome启动脚本..."
bash "$PROJECT_DIR/start_chrome_ubuntu.sh" --check-only

if [ $? -eq 0 ]; then
    echo "✅ Chrome启动脚本测试成功"
else
    echo "❌ Chrome启动脚本测试失败"
    exit 1
fi

echo "✅ Chrome Driver和启动脚本配置完成"

# 6. 设置项目权限
echo "🔐 设置项目权限..."
chmod +x "$PROJECT_DIR/crypto_trader.py"
chmod +x "$PROJECT_DIR"/*.sh 2>/dev/null || true

# 7. 配置NGINX反向代理（可选）
read -p "🌐 是否配置NGINX反向代理？(推荐，可避免端口直接暴露)(y/n): " setup_nginx

if [[ $setup_nginx == "y" || $setup_nginx == "Y" ]]; then
    echo "📦 安装和配置NGINX..."
    
    # 安装NGINX
    sudo apt install -y nginx
    
    # 备份原配置
    if [[ -f /etc/nginx/sites-available/default ]]; then
        sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
        echo "✅ 已备份原始NGINX配置"
    fi
    
    # 创建NGINX配置文件
    sudo tee /etc/nginx/sites-available/crypto-trader > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # 反向代理到Flask应用
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # WebSocket支持
    location /socket.io/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 静态文件缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # 访问和错误日志
    access_log /var/log/nginx/crypto-trader.access.log;
    error_log /var/log/nginx/crypto-trader.error.log;
}
EOF
    
    # 启用站点
    sudo ln -sf /etc/nginx/sites-available/crypto-trader /etc/nginx/sites-enabled/
    
    # 禁用默认站点
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # 测试NGINX配置
    if sudo nginx -t; then
        echo "✅ NGINX配置测试通过"
    else
        echo "❌ NGINX配置测试失败"
        exit 1
    fi
    
    # 配置防火墙
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        sudo ufw allow 'Nginx Full'
        echo "✅ 防火墙规则已配置"
    fi
    
    # 启动NGINX
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    
    if sudo systemctl is-active --quiet nginx; then
        echo "✅ NGINX服务启动成功"
        NGINX_ENABLED=true
        WEB_PORT=80
    else
        echo "❌ NGINX服务启动失败"
        sudo systemctl status nginx
        exit 1
    fi
    
    # SSL配置选项
    read -p "🔒 是否配置SSL证书？(需要域名)(y/n): " setup_ssl
    if [[ $setup_ssl == "y" || $setup_ssl == "Y" ]]; then
        read -p "请输入您的域名: " domain
        read -p "请输入您的邮箱: " email
        
        echo "📦 安装Certbot..."
        sudo apt install -y certbot python3-certbot-nginx
        
        echo "🔒 获取SSL证书..."
        sudo certbot --nginx -d $domain --email $email --agree-tos --non-interactive
        
        # 设置自动续期
        (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -
        
        echo "✅ SSL证书配置完成"
        WEB_PORT="80/443"
    fi
else
    NGINX_ENABLED=false
    WEB_PORT=5000
fi

# 8. 创建系统服务（可选）
read -p "🤖 是否创建systemd服务以便开机自启动？(y/n): " create_service

if [[ $create_service == "y" || $create_service == "Y" ]]; then
    SERVICE_NAME="run-poly@$CURRENT_USER"
    SERVICE_FILE="/etc/systemd/system/run-poly@.service"
    
    echo "📝 创建systemd服务..."
    
    # 检查项目中是否存在 run-poly.service 模板文件
    if [[ -f "$PROJECT_DIR/run-poly.service" ]]; then
        echo "📋 使用项目中的 run-poly.service 模板文件"
        
        # 根据是否启用NGINX调整服务配置
        if [[ $NGINX_ENABLED == true ]]; then
            # 使用NGINX时，保持原有配置（绑定到localhost）
            sudo cp "$PROJECT_DIR/run-poly.service" "$SERVICE_FILE"
        else
            # 不使用NGINX时，修改Flask绑定到所有接口
            sed 's/Environment=FLASK_HOST=127.0.0.1/Environment=FLASK_HOST=0.0.0.0/' "$PROJECT_DIR/run-poly.service" | \
            sed 's/After=network.target nginx.service/After=network.target/' | \
            sed 's/Requires=nginx.service//' | \
            sed 's/Description=Crypto Trading Bot with NGINX Proxy/Description=Headless Crypto Trader/' | \
            sudo tee "$SERVICE_FILE" > /dev/null
        fi
    else
        echo "⚠️  未找到 run-poly.service 模板文件，创建默认配置"
        
        # 根据是否启用NGINX调整服务配置
        if [[ $NGINX_ENABLED == true ]]; then
            # 使用NGINX时，Flask只绑定到localhost
            sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Crypto Trading Bot with NGINX Proxy
After=network.target nginx.service
Requires=nginx.service

[Service]
Type=simple
User=%i
WorkingDirectory=%h/poly_22_headless
Environment=PATH=%h/poly_22_headless/venv/bin:/usr/bin:/bin
Environment=FLASK_HOST=127.0.0.1
Environment=FLASK_PORT=5000
Environment=FLASK_ENV=production
ExecStart=%h/poly_22_headless/venv/bin/python %h/poly_22_headless/crypto_trader.py
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=30

# 安全设置
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=%h/poly_22_headless

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
        else
            # 不使用NGINX时，Flask绑定到所有接口
            sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Headless Crypto Trader
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=%h/poly_22_headless
Environment=PATH=%h/poly_22_headless/venv/bin:/usr/bin:/bin
Environment=FLASK_HOST=0.0.0.0
Environment=FLASK_PORT=5000
Environment=FLASK_ENV=production
ExecStart=%h/poly_22_headless/venv/bin/python %h/poly_22_headless/crypto_trader.py
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=30

# 安全设置
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=%h/poly_22_headless

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
        fi
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    
    echo "✅ 系统服务创建完成"
    echo "🎯 服务管理命令："
    echo "   启动服务: sudo systemctl start $SERVICE_NAME"
    echo "   停止服务: sudo systemctl stop $SERVICE_NAME"
    echo "   查看状态: sudo systemctl status $SERVICE_NAME"
    echo "   查看日志: sudo journalctl -u $SERVICE_NAME -f"
    echo "   重启服务: sudo systemctl restart $SERVICE_NAME"
fi

# 9. 配置防火墙（如果启用了ufw且未使用NGINX）
if [[ $NGINX_ENABLED != true ]] && command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo "🔥 配置防火墙规则..."
    sudo ufw allow 5000/tcp comment "Crypto Trader Web Interface"
    echo "✅ 防火墙规则添加完成（端口5000）"
fi

# 10. 创建启动脚本
echo "📜 创建启动脚本..."

# 根据是否启用NGINX创建不同的启动脚本
if [[ $NGINX_ENABLED == true ]]; then
    # 使用NGINX时，Flask只绑定到localhost
    cat > "$PROJECT_DIR/run.sh" << EOF
#!/bin/bash

# 激活虚拟环境
source "$VENV_DIR/bin/activate"

# 设置Flask环境变量
export FLASK_HOST=127.0.0.1
export FLASK_PORT=5000
export FLASK_ENV=production

# 启动交易系统
echo "🚀 启动交易系统（通过NGINX代理访问）..."
cd "$PROJECT_DIR"
python crypto_trader.py
EOF
else
    # 不使用NGINX时，Flask绑定到所有接口
    cat > "$PROJECT_DIR/run.sh" << EOF
#!/bin/bash

# 激活虚拟环境
source "$VENV_DIR/bin/activate"

# 设置Flask环境变量
export FLASK_HOST=0.0.0.0
export FLASK_PORT=5000
export FLASK_ENV=production

# 启动交易系统
echo "🚀 启动交易系统..."
cd "$PROJECT_DIR"
python crypto_trader.py
EOF
fi

chmod +x "$PROJECT_DIR/run.sh"

# 11. 显示部署信息
echo ""
echo "🎉 部署完成！"
echo "=================================================="
echo "📁 项目目录: $PROJECT_DIR"
echo "🐍 虚拟环境: $VENV_DIR"

if [[ $NGINX_ENABLED == true ]]; then
    echo "🌐 Web界面: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    echo "🔒 NGINX代理: 已启用，Flask应用安全运行在localhost:5000"
    if [[ $WEB_PORT == "80/443" ]]; then
        echo "🔐 SSL证书: 已配置，支持HTTPS访问"
    fi
else
    echo "🌐 Web界面: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    echo "⚠️  直接访问: Flask应用直接暴露在端口5000"
fi

echo "🚀 启动命令: ./run.sh"
echo "=================================================="
echo ""
echo "📋 下一步操作："
echo "1. 启动系统: 运行 './run.sh' 启动交易系统"

if [[ $NGINX_ENABLED == true ]]; then
    echo "2. 访问界面: 打开浏览器访问 http://服务器IP:$WEB_PORT"
else
    echo "2. 访问界面: 打开浏览器访问 http://服务器IP:$WEB_PORT"
fi

echo "3. 配置监控: 在Web界面设置Polymarket交易页面URL"
echo "4. 调整参数: 根据需要修改交易价格和金额设置"
echo ""
echo "💡 提示："
echo "- 系统提供Web界面进行实时监控和配置"
echo "- 支持自动交易和手动干预功能"
echo "- 建议先在测试环境验证所有功能"

if [[ $NGINX_ENABLED == true ]]; then
    echo "- NGINX反向代理提供额外的安全性和性能优化"
    echo "- 查看NGINX日志: sudo tail -f /var/log/nginx/crypto-trader.access.log"
fi

echo ""

# 询问是否立即启动
read -p "🚀 是否现在启动交易系统？(y/n): " start_now

if [[ $start_now == "y" || $start_now == "Y" ]]; then
    echo "🎯 启动交易系统..."
    ./run.sh
fi