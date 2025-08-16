#!/bin/bash

# macOS Chrome启动脚本
# 功能：启动Chrome浏览器用于自动化交易
# 版本：1.0
# 更新日期：2024-12-19

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== macOS Chrome启动脚本 ===${NC}"

# 强制杀死所有Chrome进程
echo -e "${YELLOW}正在杀死所有Chrome进程...${NC}"
pkill -f "Google Chrome" 2>/dev/null || true
pkill -f "chrome" 2>/dev/null || true
pkill -f "chromium" 2>/dev/null || true

# 等待进程完全关闭
sleep 2

# 检查是否还有Chrome进程在运行
if pgrep -f "Chrome" > /dev/null 2>&1; then
    echo -e "${RED}警告: 仍有Chrome进程在运行，强制终止...${NC}"
    pkill -9 -f "Chrome" 2>/dev/null || true
    sleep 1
fi

echo -e "${GREEN}✅ Chrome进程清理完成${NC}"

# 清理Chrome配置文件
echo -e "${YELLOW}清理Chrome配置文件...${NC}"
rm -rf ~/ChromeDebug 2>/dev/null || true
mkdir -p ~/ChromeDebug

# 启动Chrome浏览器
echo -e "${BLUE}启动Chrome浏览器...${NC}"

# Chrome启动参数
CHROME_ARGS=(
    --remote-debugging-port=9222
    --remote-debugging-address=127.0.0.1
    --user-data-dir="$HOME/ChromeDebug"
    --no-first-run
    --no-default-browser-check
    --disable-default-apps
    --disable-popup-blocking
    --disable-translate
    --disable-background-timer-throttling
    --disable-renderer-backgrounding
    --disable-backgrounding-occluded-windows
    --disable-ipc-flooding-protection
    --disable-hang-monitor
    --disable-prompt-on-repost
    --disable-sync
    --disable-web-security
    --disable-features=TranslateUI,VizDisplayCompositor
    --disable-extensions
    --disable-plugins
    --disable-images
    --disable-javascript
    --headless
    --no-sandbox
    --disable-gpu
    --disable-dev-shm-usage
    --disable-software-rasterizer
    --log-level=3
    --silent
    --disable-logging
    --disable-gpu-logging
)

# 查找Chrome可执行文件
CHROME_PATH=""
if [ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif [ -f "/Applications/Chromium.app/Contents/MacOS/Chromium" ]; then
    CHROME_PATH="/Applications/Chromium.app/Contents/MacOS/Chromium"
else
    echo -e "${RED}❌ 未找到Chrome浏览器，请先安装Google Chrome${NC}"
    exit 1
fi

echo -e "${GREEN}找到Chrome: $CHROME_PATH${NC}"

# 启动Chrome（后台运行）
echo -e "${BLUE}启动Chrome浏览器 (调试端口: 9222)...${NC}"
"$CHROME_PATH" "${CHROME_ARGS[@]}" > /dev/null 2>&1 &

# 等待Chrome启动
sleep 3

# 检查Chrome是否成功启动
if curl -s http://127.0.0.1:9222/json > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Chrome启动成功，调试端口已可用${NC}"
else
    echo -e "${RED}❌ Chrome启动失败或调试端口不可用${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Chrome启动完成！${NC}"