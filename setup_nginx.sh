#!/bin/bash

# NGINX反向代理部署脚本
# 用于Crypto Trader应用的NGINX配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    log_info "检测到操作系统: $OS $VER"
}

# 安装NGINX
install_nginx() {
    log_info "开始安装NGINX..."
    
    if command -v nginx &> /dev/null; then
        log_warning "NGINX已安装，跳过安装步骤"
        return
    fi
    
    case $OS in
        *"Ubuntu"*|*"Debian"*)
            apt update
            apt install -y nginx
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            yum install -y epel-release
            yum install -y nginx
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    log_success "NGINX安装完成"
}

# 配置NGINX
configure_nginx() {
    log_info "配置NGINX反向代理..."
    
    # 备份原配置
    if [[ -f /etc/nginx/sites-available/default ]]; then
        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
        log_info "已备份原始配置文件"
    fi
    
    # 复制配置文件
    cp nginx.conf /etc/nginx/sites-available/crypto-trader
    
    # 创建软链接
    if [[ -L /etc/nginx/sites-enabled/crypto-trader ]]; then
        rm /etc/nginx/sites-enabled/crypto-trader
    fi
    ln -s /etc/nginx/sites-available/crypto-trader /etc/nginx/sites-enabled/
    
    # 禁用默认站点（可选）
    if [[ -L /etc/nginx/sites-enabled/default ]]; then
        rm /etc/nginx/sites-enabled/default
        log_info "已禁用默认站点"
    fi
    
    log_success "NGINX配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 检查防火墙类型
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian UFW
        ufw allow 'Nginx Full'
        ufw allow 22  # 确保SSH端口开放
        log_info "UFW防火墙规则已配置"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewalld
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        log_info "firewalld防火墙规则已配置"
    else
        log_warning "未检测到防火墙，请手动配置端口80和443"
    fi
}

# 测试NGINX配置
test_nginx() {
    log_info "测试NGINX配置..."
    
    if nginx -t; then
        log_success "NGINX配置测试通过"
    else
        log_error "NGINX配置测试失败"
        exit 1
    fi
}

# 启动服务
start_services() {
    log_info "启动NGINX服务..."
    
    systemctl enable nginx
    systemctl restart nginx
    
    if systemctl is-active --quiet nginx; then
        log_success "NGINX服务启动成功"
    else
        log_error "NGINX服务启动失败"
        systemctl status nginx
        exit 1
    fi
}

# 生成SSL证书（Let's Encrypt）
setup_ssl() {
    read -p "是否要配置SSL证书？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入您的域名: " domain
        read -p "请输入您的邮箱: " email
        
        log_info "安装Certbot..."
        
        case $OS in
            *"Ubuntu"*|*"Debian"*)
                apt install -y certbot python3-certbot-nginx
                ;;
            *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
                yum install -y certbot python3-certbot-nginx
                ;;
        esac
        
        log_info "获取SSL证书..."
        certbot --nginx -d $domain --email $email --agree-tos --non-interactive
        
        # 设置自动续期
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        
        log_success "SSL证书配置完成"
    fi
}

# 显示状态信息
show_status() {
    echo
    log_success "=== NGINX反向代理部署完成 ==="
    echo
    echo "服务状态:"
    systemctl status nginx --no-pager -l
    echo
    echo "监听端口:"
    netstat -tlnp | grep nginx || ss -tlnp | grep nginx
    echo
    echo "配置文件位置:"
    echo "  - 主配置: /etc/nginx/sites-available/crypto-trader"
    echo "  - 软链接: /etc/nginx/sites-enabled/crypto-trader"
    echo
    echo "日志文件:"
    echo "  - 访问日志: /var/log/nginx/crypto-trader.access.log"
    echo "  - 错误日志: /var/log/nginx/crypto-trader.error.log"
    echo
    log_info "请确保:"
    echo "  1. 修改配置文件中的域名 (your-domain.com)"
    echo "  2. 确保Crypto Trader应用在localhost:5000运行"
    echo "  3. 如果使用SSL，请配置正确的证书路径"
    echo
}

# 主函数
main() {
    echo "=== Crypto Trader NGINX反向代理部署脚本 ==="
    echo
    
    check_root
    detect_os
    install_nginx
    configure_nginx
    configure_firewall
    test_nginx
    start_services
    setup_ssl
    show_status
    
    log_success "部署完成！"
}

# 运行主函数
main "$@"