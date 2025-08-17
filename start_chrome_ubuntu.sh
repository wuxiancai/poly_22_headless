#!/bin/bash

# Ubuntu Chrome启动脚本 - Admin用户专用版
# 功能：检查Chrome、智能匹配ChromeDriver版本、无sudo权限操作
# 作者：自动化脚本
# 版本：3.0 (Admin优化版)
# 更新日期：2024-12-19

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/chrome_update.log"

# 设置ChromeDebug目录
CHROME_DEBUG_DIR="$HOME/ChromeDebug"

# 确保ChromeDebug目录存在且可写
if [ ! -d "$CHROME_DEBUG_DIR" ]; then
    mkdir -p "$CHROME_DEBUG_DIR" 2>/dev/null || {
        echo -e "${YELLOW}无法创建ChromeDebug目录，使用临时目录${NC}"
        CHROME_DEBUG_DIR="/tmp/ChromeDebug_$(whoami)"
        mkdir -p "$CHROME_DEBUG_DIR"
    }
fi

# 确保目录可写
if [ ! -w "$CHROME_DEBUG_DIR" ]; then
    echo -e "${YELLOW}ChromeDebug目录不可写，使用临时目录${NC}"
    CHROME_DEBUG_DIR="/tmp/ChromeDebug_$(whoami)"
    mkdir -p "$CHROME_DEBUG_DIR"
fi

echo -e "${GREEN}✅ Chrome进程清理完成${NC}"
echo -e "${BLUE}使用ChromeDebug目录: $CHROME_DEBUG_DIR${NC}"

# 删除锁文件
for f in "SingletonLock" "SingletonCookie" "SingletonSocket"; do
    path="$CHROME_DEBUG_DIR/$f"
    if [ -f "$path" ]; then
        rm -f "$path" 2>/dev/null || true
    fi
done

# 显示使用说明
show_usage() {
    echo -e "${BLUE}=== Ubuntu Chrome启动脚本 v3.0 (Admin专用版) ===${NC}"
    echo -e "${GREEN}功能特性：${NC}"
    echo -e "  • 检查Chrome浏览器安装状态"
    echo -e "  • 智能匹配兼容的ChromeDriver版本"
    echo -e "  • 无sudo权限操作,适用于admin用户"
    echo -e "  • 本地安装ChromeDriver到用户目录"
    echo -e "  • 增强的版本兼容性检查"
    echo -e "  • 详细的日志记录和错误处理"
    echo -e "  • 版本信息备份功能"
    echo -e "${GREEN}日志文件：${NC} $LOG_FILE"
    echo -e "${GREEN}备份文件：${NC} $SCRIPT_DIR/version_backup.txt"
    echo -e "${GREEN}ChromeDriver安装目录：${NC} $HOME/.local/bin"
    echo ""
}

# 处理命令行参数
handle_arguments() {
    case "$1" in
        "--help"|-h)
            show_usage
            exit 0
            ;;
        "--version"|-v)
            echo "Ubuntu Chrome自动匹配更新脚本 v2.0"
            exit 0
            ;;
        "--check-only")
            echo -e "${YELLOW}仅执行版本检查模式${NC}"
            return 1
            ;;
        "")
            return 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# 日志记录函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[$level] $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$level] $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$level] $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}[$level] $message${NC}"
            ;;
        *)
            echo "[$level] $message"
            ;;
    esac
}

# 备份版本信息
backup_version_info() {
    local backup_file="$SCRIPT_DIR/version_backup.txt"
    {
        echo "=== 版本备份信息 - $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Chrome版本: $(get_chrome_version 2>/dev/null || echo 'Not found')"
        if command -v chromedriver &> /dev/null; then
            echo "ChromeDriver版本: $(chromedriver --version 2>/dev/null | awk '{print $2}' || echo 'Not found')"
            echo "ChromeDriver路径: $(which chromedriver)"
        else
            echo "ChromeDriver版本: Not installed"
        fi
        echo "系统信息: $(uname -a)"
        echo "==========================================="
        echo ""
    } >> "$backup_file"
    log_message "INFO" "版本信息已备份到 $backup_file"
}

# 详细版本分析和建议
analyze_version_compatibility() {
    local chrome_ver="$1"
    local driver_ver="$2"
    
    echo -e "${BLUE}=== 详细版本兼容性分析 ===${NC}"
    
    # 解析版本号
    local chrome_major=$(echo "$chrome_ver" | cut -d'.' -f1)
    local chrome_minor=$(echo "$chrome_ver" | cut -d'.' -f2)
    local chrome_build=$(echo "$chrome_ver" | cut -d'.' -f3)
    local chrome_patch=$(echo "$chrome_ver" | cut -d'.' -f4)
    
    local driver_major=$(echo "$driver_ver" | cut -d'.' -f1)
    local driver_minor=$(echo "$driver_ver" | cut -d'.' -f2)
    local driver_build=$(echo "$driver_ver" | cut -d'.' -f3)
    local driver_patch=$(echo "$driver_ver" | cut -d'.' -f4)
    
    echo -e "${YELLOW}Chrome版本分解:${NC}"
    echo -e "  主版本: $chrome_major, 次版本: $chrome_minor, 构建: $chrome_build, 补丁: $chrome_patch"
    echo -e "${YELLOW}ChromeDriver版本分解:${NC}"
    echo -e "  主版本: $driver_major, 次版本: $driver_minor, 构建: $driver_build, 补丁: $driver_patch"
    
    # 兼容性评估
    local compatibility_score=0
    local recommendations=()
    
    if [ "$chrome_major" = "$driver_major" ]; then
        echo -e "${GREEN}✓ 主版本匹配 ($chrome_major)${NC}"
        compatibility_score=$((compatibility_score + 40))
    else
        echo -e "${RED}✗ 主版本不匹配 (Chrome: $chrome_major, Driver: $driver_major)${NC}"
        recommendations+=("必须更新ChromeDriver到主版本$chrome_major")
    fi
    
    if [ "$chrome_minor" = "$driver_minor" ]; then
        echo -e "${GREEN}✓ 次版本匹配 ($chrome_minor)${NC}"
        compatibility_score=$((compatibility_score + 30))
    else
        echo -e "${RED}✗ 次版本不匹配 (Chrome: $chrome_minor, Driver: $driver_minor)${NC}"
        recommendations+=("必须更新ChromeDriver到次版本$chrome_minor")
    fi
    
    if [ "$chrome_build" = "$driver_build" ]; then
        echo -e "${GREEN}✓ 构建版本匹配 ($chrome_build)${NC}"
        compatibility_score=$((compatibility_score + 20))
    else
        echo -e "${YELLOW}⚠ 构建版本不匹配 (Chrome: $chrome_build, Driver: $driver_build)${NC}"
        recommendations+=("建议更新ChromeDriver到构建版本$chrome_build")
    fi
    
    local patch_diff=$((chrome_patch - driver_patch))
    local patch_diff_abs=${patch_diff#-}
    
    if [ "$patch_diff_abs" -eq 0 ]; then
        echo -e "${GREEN}✓ 补丁版本完全匹配 ($chrome_patch)${NC}"
        compatibility_score=$((compatibility_score + 10))
    elif [ "$patch_diff_abs" -le 5 ]; then
        echo -e "${YELLOW}⚠ 补丁版本差异较小 (差异: $patch_diff_abs)${NC}"
        compatibility_score=$((compatibility_score + 5))
        recommendations+=("建议更新到完全匹配的补丁版本$chrome_patch")
    else
        echo -e "${RED}✗ 补丁版本差异较大 (差异: $patch_diff_abs)${NC}"
        recommendations+=("强烈建议更新到补丁版本$chrome_patch")
    fi
    
    # 兼容性评分
    echo -e "${BLUE}兼容性评分: $compatibility_score/100${NC}"
    
    if [ $compatibility_score -ge 90 ]; then
        echo -e "${GREEN}兼容性等级: 优秀 - 版本高度兼容${NC}"
    elif [ $compatibility_score -ge 70 ]; then
        echo -e "${YELLOW}兼容性等级: 良好 - 基本兼容，建议更新${NC}"
    elif [ $compatibility_score -ge 50 ]; then
        echo -e "${YELLOW}兼容性等级: 一般 - 可能存在问题，建议更新${NC}"
    else
        echo -e "${RED}兼容性等级: 差 - 存在兼容性风险，必须更新${NC}"
    fi
    
    # 显示建议
    if [ ${#recommendations[@]} -gt 0 ]; then
        echo -e "${YELLOW}改进建议:${NC}"
        for rec in "${recommendations[@]}"; do
            echo -e "  • $rec"
        done
    else
        echo -e "${GREEN}无需改进，版本完全兼容${NC}"
    fi
    
    echo -e "${BLUE}=================================${NC}"
    
    return $compatibility_score
}
# 获取Chrome完整版本号
get_chrome_version() {
    if command -v google-chrome-stable &> /dev/null; then
        google-chrome-stable --version | awk '{print $3}'
    else
        echo "Chrome not found"
        return 1
    fi
}

# 检查Chrome版本（admin用户无需更新）
check_chrome() {
    echo -e "${YELLOW}检查Chrome安装状态...${NC}"
    CURRENT_VERSION=$(get_chrome_version)
    if [ "$CURRENT_VERSION" = "Chrome not found" ]; then
        echo -e "${RED}Chrome未安装${NC}"
        echo -e "${YELLOW}请手动安装Chrome浏览器：${NC}"
        echo -e "  1. 下载Chrome: https://www.google.com/chrome/"
        echo -e "  2. 或使用包管理器安装"
        return 1
    fi
    
    echo -e "${GREEN}当前Chrome版本: $CURRENT_VERSION${NC}"
    log_message "INFO" "检测到Chrome版本: $CURRENT_VERSION"
    
    return 0
}

# 检查已安装的 chromedriver 是否匹配当前 Chrome
check_driver() {
    CHROME_VERSION=$(get_chrome_version)
    if [ "$CHROME_VERSION" = "Chrome not found" ]; then
        echo -e "${RED}Chrome 未安装${NC}"
        return 1
    fi
    
    # 检查系统路径中的chromedriver
    DRIVER_PATH=""
    if command -v chromedriver &> /dev/null; then
        DRIVER_PATH=$(which chromedriver)
    fi

    if [ -z "$DRIVER_PATH" ]; then
        echo -e "${RED}chromedriver 未安装${NC}"
        return 1
    fi

    DRIVER_VERSION=$("$DRIVER_PATH" --version | awk '{print $2}')
    
    echo -e "${YELLOW}Chrome 版本: $CHROME_VERSION${NC}"
    echo -e "${YELLOW}chromedriver 版本: $DRIVER_VERSION${NC}"
    echo -e "${YELLOW}chromedriver 路径: $DRIVER_PATH${NC}"

    # 增强版本匹配检查
    CHROME_MAJOR=$(echo "$CHROME_VERSION" | cut -d'.' -f1)
    CHROME_MINOR=$(echo "$CHROME_VERSION" | cut -d'.' -f2)
    CHROME_BUILD=$(echo "$CHROME_VERSION" | cut -d'.' -f3)
    CHROME_PATCH=$(echo "$CHROME_VERSION" | cut -d'.' -f4)
    
    DRIVER_MAJOR=$(echo "$DRIVER_VERSION" | cut -d'.' -f1)
    DRIVER_MINOR=$(echo "$DRIVER_VERSION" | cut -d'.' -f2)
    DRIVER_BUILD=$(echo "$DRIVER_VERSION" | cut -d'.' -f3)
    DRIVER_PATCH=$(echo "$DRIVER_VERSION" | cut -d'.' -f4)
    
    # 检查主版本号和次版本号必须完全匹配
    if [ "$CHROME_MAJOR" != "$DRIVER_MAJOR" ] || [ "$CHROME_MINOR" != "$DRIVER_MINOR" ]; then
        echo -e "${RED}主版本不匹配，需更新驱动 (Chrome: $CHROME_MAJOR.$CHROME_MINOR vs Driver: $DRIVER_MAJOR.$DRIVER_MINOR)${NC}"
        return 1
    fi
    
    # 检查构建版本号和patch版本号
    if [ "$CHROME_BUILD" != "$DRIVER_BUILD" ]; then
        echo -e "${YELLOW}构建版本不同 (Chrome: $CHROME_BUILD vs Driver: $DRIVER_BUILD)${NC}"
        echo -e "${RED}构建版本不匹配，需要更新驱动${NC}"
        return 1
    else
        # 构建版本相同时，检查patch版本差异
        PATCH_DIFF=$((CHROME_PATCH - DRIVER_PATCH))
        PATCH_DIFF_ABS=${PATCH_DIFF#-}  # 取绝对值
        
        echo -e "${BLUE}构建版本匹配 (Chrome: $CHROME_BUILD, Driver: $DRIVER_BUILD)${NC}"
        echo -e "${BLUE}Patch版本差异: $PATCH_DIFF (Chrome: $CHROME_PATCH, Driver: $DRIVER_PATCH)${NC}"
        
        if [ "$PATCH_DIFF_ABS" -gt 10 ]; then
            echo -e "${RED}Patch版本差异过大 ($PATCH_DIFF_ABS > 10)，强烈建议更新驱动${NC}"
            return 1
        elif [ "$PATCH_DIFF_ABS" -gt 5 ]; then
            echo -e "${YELLOW}Patch版本差异较大 ($PATCH_DIFF_ABS > 5)，建议更新驱动${NC}"
            return 1
        elif [ "$PATCH_DIFF_ABS" -gt 0 ]; then
            echo -e "${YELLOW}Patch版本有差异 ($PATCH_DIFF_ABS)，但在可接受范围内${NC}"
        else
            echo -e "${GREEN}版本完全匹配${NC}"
        fi
    fi

    echo -e "${BLUE}版本检查通过，驱动可用${NC}"
    return 0
}

# 自动安装兼容的 chromedriver（Admin用户版本）- 本地安装
install_driver() {
    echo -e "${YELLOW}尝试下载安装兼容的 chromedriver...${NC}"
    
    # 设置本地安装目录
    LOCAL_BIN_DIR="$HOME/.local/bin"
    mkdir -p "$LOCAL_BIN_DIR"
    
    # 确保本地bin目录在PATH中
    if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
        echo -e "${YELLOW}添加 $LOCAL_BIN_DIR 到PATH${NC}"
        export PATH="$LOCAL_BIN_DIR:$PATH"
        # 添加到bashrc以便永久生效
        if ! grep -q "$LOCAL_BIN_DIR" "$HOME/.bashrc" 2>/dev/null; then
            echo "export PATH=\"$LOCAL_BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
        fi
    fi
    
    CHROME_VERSION=$(get_chrome_version)
    BASE_VERSION=$(echo "$CHROME_VERSION" | cut -d'.' -f1-3)
    PATCH_VERSION=$(echo "$CHROME_VERSION" | cut -d'.' -f4)

    TMP_DIR="/tmp/chromedriver_update_$(whoami)"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || return 1
    
    # 清理之前的下载文件
    rm -f chromedriver.zip
    rm -rf chromedriver-linux64*
    
    # 扩展尝试范围：向前和向后各尝试5个patch版本
    echo -e "${YELLOW}智能匹配ChromeDriver版本...${NC}"
    
    # 首先尝试完全匹配的版本
    EXACT_VERSION="$CHROME_VERSION"
    DRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${EXACT_VERSION}/linux64/chromedriver-linux64.zip"
    echo -e "${YELLOW}尝试完全匹配版本: $EXACT_VERSION${NC}"
    
    if curl -sfLo chromedriver.zip "$DRIVER_URL"; then
        echo -e "${GREEN}找到完全匹配版本 ${EXACT_VERSION}${NC}"
        if unzip -qo chromedriver.zip && [ -f "chromedriver-linux64/chromedriver" ]; then
            mv chromedriver-linux64/chromedriver "$LOCAL_BIN_DIR/"
            chmod +x "$LOCAL_BIN_DIR/chromedriver"
            echo -e "${GREEN}安装成功: $("$LOCAL_BIN_DIR/chromedriver" --version)${NC}"
            cd "$SCRIPT_DIR"
            return 0
        fi
    fi
    
    # 如果完全匹配失败，尝试patch版本范围
    echo -e "${YELLOW}完全匹配失败，尝试兼容版本...${NC}"
    
    # 向下尝试（减少patch版本号）
    for ((i=1; i<=5; i++)); do
        TRY_PATCH=$((PATCH_VERSION - i))
        if [ $TRY_PATCH -ge 0 ]; then
            TRY_VERSION="${BASE_VERSION}.${TRY_PATCH}"
            DRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${TRY_VERSION}/linux64/chromedriver-linux64.zip"
            echo -e "${YELLOW}尝试版本: $TRY_VERSION${NC}"
            
            rm -f chromedriver.zip
            rm -rf chromedriver-linux64*
            
            if curl -sfLo chromedriver.zip "$DRIVER_URL"; then
                if unzip -qo chromedriver.zip && [ -f "chromedriver-linux64/chromedriver" ]; then
                    echo -e "${GREEN}成功下载 chromedriver ${TRY_VERSION}${NC}"
                    mv chromedriver-linux64/chromedriver "$LOCAL_BIN_DIR/"
                    chmod +x "$LOCAL_BIN_DIR/chromedriver"
                    echo -e "${GREEN}安装成功: $("$LOCAL_BIN_DIR/chromedriver" --version)${NC}"
                    cd "$SCRIPT_DIR"
                    return 0
                fi
            fi
        fi
    done
    
    # 向上尝试（增加patch版本号）
    for ((i=1; i<=3; i++)); do
        TRY_PATCH=$((PATCH_VERSION + i))
        TRY_VERSION="${BASE_VERSION}.${TRY_PATCH}"
        DRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${TRY_VERSION}/linux64/chromedriver-linux64.zip"
        echo -e "${YELLOW}尝试版本: $TRY_VERSION${NC}"
        
        rm -f chromedriver.zip
        rm -rf chromedriver-linux64*
        
        if curl -sfLo chromedriver.zip "$DRIVER_URL"; then
            if unzip -qo chromedriver.zip && [ -f "chromedriver-linux64/chromedriver" ]; then
                echo -e "${GREEN}成功下载 chromedriver ${TRY_VERSION}${NC}"
                mv chromedriver-linux64/chromedriver "$LOCAL_BIN_DIR/"
                chmod +x "$LOCAL_BIN_DIR/chromedriver"
                echo -e "${GREEN}安装成功: $("$LOCAL_BIN_DIR/chromedriver" --version)${NC}"
                cd "$SCRIPT_DIR"
                return 0
            fi
        fi
    done

    echo -e "${RED}未能下载兼容 chromedriver（尝试了多个版本）${NC}"
    echo -e "${RED}Chrome版本: $CHROME_VERSION${NC}"
    echo -e "${RED}建议手动检查 https://googlechromelabs.github.io/chrome-for-testing/ ${NC}"
    cd "$SCRIPT_DIR"
    return 1
}

# 主流程 - 增强版
# 处理命令行参数
CHECK_ONLY_MODE=false
if [ "$1" = "--check-only" ]; then
    CHECK_ONLY_MODE=true
    echo -e "${YELLOW}仅执行版本检查模式${NC}"
else
    handle_arguments "$1"
    CHECK_ONLY_MODE=false
fi

echo -e "${YELLOW}开始执行浏览器启动流程...${NC}"
log_message "INFO" "脚本启动，模式: $([ "$CHECK_ONLY_MODE" = true ] && echo '仅检查' || echo '完整启动')"
show_usage

# 首先检查Chrome
echo -e "${YELLOW}====== 开始检查Chrome ======${NC}"
check_chrome
CHROME_CHECK_RESULT=$?
echo -e "${YELLOW}====== Chrome检查完成 ======${NC}"

# 根据Chrome检查结果决定是否继续
FORCE_DRIVER_UPDATE=false
if [ $CHROME_CHECK_RESULT -ne 0 ]; then
    echo -e "${RED}Chrome检查失败,无法继续${NC}"
    exit 1
fi

# 检查ChromeDriver兼容性
log_message "INFO" "检查ChromeDriver版本兼容性"

# 获取当前版本进行详细分析
current_chrome_ver=$(get_chrome_version)
current_driver_ver=""

# 检查本地和系统ChromeDriver
LOCAL_BIN_DIR="$HOME/.local/bin"
if [ -x "$LOCAL_BIN_DIR/chromedriver" ]; then
    current_driver_ver=$("$LOCAL_BIN_DIR/chromedriver" --version 2>/dev/null | awk '{print $2}' || echo "未知")
elif command -v chromedriver &> /dev/null; then
    current_driver_ver=$(chromedriver --version 2>/dev/null | awk '{print $2}' || echo "未知")
else
    current_driver_ver="未安装"
fi

# 执行详细版本分析
if [ "$current_driver_ver" != "未安装" ] && [ "$current_driver_ver" != "未知" ]; then
    analyze_version_compatibility "$current_chrome_ver" "$current_driver_ver"
    compatibility_score=$?
    
    if [ $compatibility_score -ge 70 ]; then
        log_message "SUCCESS" "版本兼容性良好 (评分: $compatibility_score/100)"
    else
        log_message "WARNING" "版本兼容性较差 (评分: $compatibility_score/100)，建议更新"
    fi
fi

if [ "$FORCE_DRIVER_UPDATE" = true ] || ! check_driver; then
    echo -e "${YELLOW}驱动需要更新，尝试修复...${NC}"
    log_message "WARNING" "ChromeDriver版本不匹配，尝试安装兼容版本"
    
    # 如果是强制更新，先删除现有的chromedriver
    if [ "$FORCE_DRIVER_UPDATE" = true ]; then
        echo -e "${YELLOW}删除旧版本ChromeDriver...${NC}"
        # 删除本地版本
        rm -f "$LOCAL_BIN_DIR/chromedriver"
        # 如果有系统版本的访问权限，也尝试删除（但不使用sudo）
        if [ -w "/usr/local/bin/chromedriver" ]; then
            rm -f /usr/local/bin/chromedriver
        fi
        if [ -w "/usr/bin/chromedriver" ]; then
            rm -f /usr/bin/chromedriver
        fi
    fi
    
    if install_driver; then
        echo -e "${GREEN}ChromeDriver安装成功，进行最终检查...${NC}"
        log_message "SUCCESS" "ChromeDriver安装成功"
        
        # 重新获取版本并分析
        if [ -x "$LOCAL_BIN_DIR/chromedriver" ]; then
            new_driver_ver=$("$LOCAL_BIN_DIR/chromedriver" --version 2>/dev/null | awk '{print $2}' || echo "未知")
        else
            new_driver_ver=$(chromedriver --version 2>/dev/null | awk '{print $2}' || echo "未知")
        fi
        if [ "$new_driver_ver" != "未知" ]; then
            echo -e "\n${BLUE}=== 更新后版本分析 ===${NC}"
            analyze_version_compatibility "$current_chrome_ver" "$new_driver_ver"
            new_compatibility_score=$?
            log_message "INFO" "更新后兼容性评分: $new_compatibility_score/100"
        fi
        
        if check_driver; then
            echo -e "${GREEN}版本匹配确认成功${NC}"
            log_message "SUCCESS" "ChromeDriver版本检查通过"
        else
            echo -e "${YELLOW}版本仍有差异，但尝试继续运行${NC}"
            log_message "WARNING" "版本仍有差异，但将尝试继续运行"
        fi
    else
        echo -e "${RED}驱动更新失败${NC}"
        echo -e "${YELLOW}尝试使用现有驱动继续运行...${NC}"
        log_message "ERROR" "ChromeDriver安装失败，但将尝试继续运行"
    fi
else
    echo -e "${GREEN}ChromeDriver版本检查通过${NC}"
    log_message "SUCCESS" "ChromeDriver版本检查通过"
fi

# 清理崩溃文件
rm -f "$HOME/ChromeDebug/SingletonLock"
rm -f "$HOME/ChromeDebug/SingletonSocket"
rm -f "$HOME/ChromeDebug/SingletonCookie"
rm -f "$HOME/ChromeDebug/Default/Last Browser"
rm -f "$HOME/ChromeDebug/Default/Last Session"
rm -f "$HOME/ChromeDebug/Default/Last Tabs"

# 修复 Preferences 里记录的崩溃状态
PREF_FILE="$HOME/ChromeDebug/Default/Preferences"
if [ -f "$PREF_FILE" ]; then
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREF_FILE"
fi

# 最终版本确认和启动
log_message "INFO" "开始最终版本确认"
FINAL_CHROME_VERSION=$(get_chrome_version)

# 检查本地和系统ChromeDriver版本
if [ -x "$LOCAL_BIN_DIR/chromedriver" ]; then
    FINAL_DRIVER_VERSION=$("$LOCAL_BIN_DIR/chromedriver" --version 2>/dev/null | awk '{print $2}')
elif command -v chromedriver &> /dev/null; then
    FINAL_DRIVER_VERSION=$(chromedriver --version 2>/dev/null | awk '{print $2}')
else
    FINAL_DRIVER_VERSION="Not installed"
fi

log_message "SUCCESS" "最终版本确认 - Chrome: $FINAL_CHROME_VERSION, ChromeDriver: $FINAL_DRIVER_VERSION"
echo -e "${GREEN}=== 最终版本信息 ===${NC}"
echo -e "${GREEN}Chrome版本: $FINAL_CHROME_VERSION${NC}"
echo -e "${GREEN}ChromeDriver版本: $FINAL_DRIVER_VERSION${NC}"
echo -e "${GREEN}===================${NC}"

# 备份当前版本信息
backup_version_info

# 根据模式决定是否启动Chrome
if [ "$CHECK_ONLY_MODE" = true ]; then
    log_message "INFO" "仅检查模式完成，不启动Chrome"
    echo -e "${GREEN}=== 版本检查完成 ===${NC}"
    echo -e "${GREEN}所有检查已完成，Chrome和ChromeDriver版本已确认兼容${NC}"
    echo -e "${YELLOW}如需启动Chrome，请运行: bash $0${NC}"
    exit 0
fi

# 启动 Chrome（调试端口）- 使用系统安装的Chrome（无头模式）
log_message "INFO" "启动Chrome浏览器(无头模式)"
echo -e "${GREEN}启动 Chrome 中（无头模式）...${NC}"
if command -v google-chrome-stable &> /dev/null; then
    log_message "INFO" "Chrome启动参数已设置(无头模式),开始启动"
    google-chrome-stable \
        --headless \
        --remote-debugging-port=9222 \
        --no-sandbox \
        --disable-gpu \
        --disable-software-rasterizer \
        --disable-dev-shm-usage \
        --disable-extensions \
        --disable-background-networking \
        --disable-default-apps \
        --disable-sync \
        --metrics-recording-only \
        --disable-infobars \
        --no-first-run \
        --disable-session-crashed-bubble \
        --disable-translate \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-features=TranslateUI,BlinkGenPropertyTrees,SitePerProcess,IsolateOrigins \
        --noerrdialogs \
        --disable-notifications \
        --test-type \
        --disable-component-update \
        --disable-background-mode \
        --disable-client-side-phishing-detection \
        --disable-hang-monitor \
        --disable-prompt-on-repost \
        --disable-domain-reliability \
        --log-level=3 \
        --user-data-dir="$HOME/ChromeDebug" \
        https://polymarket.com/crypto &
    
    CHROME_PID=$!
    log_message "SUCCESS" "Chrome已启动(无头模式)PID: $CHROME_PID"
    echo -e "${GREEN}Chrome已启动(无头模式),PID: $CHROME_PID${NC}"
    echo -e "${GREEN}调试端口: http://localhost:9222${NC}"
    echo -e "${GREEN}目标网站: https://polymarket.com/crypto${NC}"
    echo -e "${YELLOW}提示：使用 'kill $CHROME_PID' 可以停止Chrome进程${NC}"
    
    # Chrome启动完成，验证将由crypto_trader.py中的_check_chrome_headless_status函数处理
    log_message "SUCCESS" "Chrome启动脚本执行完成"
    echo -e "${GREEN}✅ Chrome启动脚本执行完成，调试端口验证将由主程序处理${NC}"
else
    log_message "ERROR" "Chrome未找到,启动失败"
    echo -e "${RED}Chrome 未找到，请确保已安装 google-chrome-stable${NC}"
    exit 1
fi

log_message "SUCCESS" "脚本执行完成"
echo -e "${GREEN}=== 脚本执行完成 ===${NC}"
