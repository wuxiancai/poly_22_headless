# NGINX反向代理部署指南

本指南将帮助您为Crypto Trader应用配置NGINX反向代理，确保端口不直接暴露在公网上。

## 📋 部署概述

### 架构说明
```
互联网 → NGINX (端口80/443) → Flask应用 (localhost:5000)
```

- **NGINX**: 作为反向代理服务器，处理外部请求
- **Flask应用**: 仅监听localhost:5000，不直接暴露
- **SSL终止**: NGINX处理HTTPS加密，内部使用HTTP通信

## 🚀 快速部署

### 方法一：自动部署脚本

```bash
# 1. 确保具有root权限
sudo ./setup_nginx.sh
```

### 方法二：手动部署

#### 1. 安装NGINX

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install nginx
```

**CentOS/RHEL:**
```bash
sudo yum install epel-release
sudo yum install nginx
```

#### 2. 配置NGINX

**选择配置文件:**
- `nginx.conf` - 完整版（包含SSL配置）
- `nginx-simple.conf` - 简化版（仅HTTP）

**部署配置:**
```bash
# 复制配置文件
sudo cp nginx-simple.conf /etc/nginx/sites-available/crypto-trader

# 创建软链接
sudo ln -s /etc/nginx/sites-available/crypto-trader /etc/nginx/sites-enabled/

# 禁用默认站点（可选）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重启NGINX
sudo systemctl restart nginx
sudo systemctl enable nginx
```

#### 3. 配置防火墙

**Ubuntu (UFW):**
```bash
sudo ufw allow 'Nginx Full'
sudo ufw allow 22  # 确保SSH访问
```

**CentOS (firewalld):**
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

#### 4. 更新应用配置

**更新systemd服务:**
```bash
# 复制更新的服务文件
sudo cp run-poly.service /etc/systemd/system/

# 重新加载systemd
sudo systemctl daemon-reload

# 重启服务
sudo systemctl restart run-poly
```

## 🔧 配置详解

### NGINX配置要点

1. **反向代理设置**
   ```nginx
   proxy_pass http://127.0.0.1:5000;
   proxy_set_header Host $host;
   proxy_set_header X-Real-IP $remote_addr;
   ```

2. **WebSocket支持**
   ```nginx
   proxy_http_version 1.1;
   proxy_set_header Upgrade $http_upgrade;
   proxy_set_header Connection "upgrade";
   ```

3. **安全头设置**
   ```nginx
   add_header X-Frame-Options SAMEORIGIN;
   add_header X-Content-Type-Options nosniff;
   add_header X-XSS-Protection "1; mode=block";
   ```

### 应用配置要点

1. **环境变量**
   ```bash
   FLASK_HOST=127.0.0.1  # 仅监听本地
   FLASK_PORT=5000       # 默认端口
   FLASK_ENV=production  # 生产环境
   ```

2. **systemd服务依赖**
   ```ini
   After=network.target nginx.service
   Requires=nginx.service
   ```

## 🔒 SSL配置（可选）

### 使用Let's Encrypt

```bash
# 安装Certbot
sudo apt install certbot python3-certbot-nginx  # Ubuntu
sudo yum install certbot python3-certbot-nginx  # CentOS

# 获取证书
sudo certbot --nginx -d your-domain.com

# 设置自动续期
sudo crontab -e
# 添加: 0 12 * * * /usr/bin/certbot renew --quiet
```

### 手动SSL配置

1. 获取SSL证书文件
2. 修改`nginx.conf`中的证书路径
3. 重启NGINX服务

## 📊 监控和维护

### 日志文件位置

- **NGINX访问日志**: `/var/log/nginx/crypto-trader.access.log`
- **NGINX错误日志**: `/var/log/nginx/crypto-trader.error.log`
- **应用日志**: `/home/admin/poly_22_headless/run.log`

### 常用命令

```bash
# 查看NGINX状态
sudo systemctl status nginx

# 查看应用状态
sudo systemctl status run-poly

# 重新加载NGINX配置
sudo nginx -s reload

# 查看实时日志
sudo tail -f /var/log/nginx/crypto-trader.access.log
sudo journalctl -u run-poly -f

# 测试NGINX配置
sudo nginx -t
```

### 性能监控

```bash
# 查看连接数
sudo netstat -tlnp | grep nginx

# 查看进程状态
sudo ps aux | grep nginx
sudo ps aux | grep python

# 查看端口占用
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :5000
```

## 🛠️ 故障排除

### 常见问题

1. **502 Bad Gateway**
   - 检查Flask应用是否运行在localhost:5000
   - 查看应用日志确认启动状态
   - 验证防火墙设置

2. **连接超时**
   - 检查NGINX配置中的超时设置
   - 确认上游服务响应正常
   - 查看系统资源使用情况

3. **SSL证书问题**
   - 验证证书文件路径和权限
   - 检查证书有效期
   - 确认域名解析正确

### 调试步骤

```bash
# 1. 检查服务状态
sudo systemctl status nginx run-poly

# 2. 测试本地连接
curl -I http://localhost:5000

# 3. 测试NGINX代理
curl -I http://localhost

# 4. 查看详细日志
sudo journalctl -u nginx -f
sudo journalctl -u run-poly -f

# 5. 验证配置语法
sudo nginx -t
```

## 📈 性能优化

### NGINX优化

```nginx
# 工作进程数
worker_processes auto;

# 连接数限制
worker_connections 1024;

# 启用gzip压缩
gzip on;
gzip_types text/plain text/css application/json application/javascript;

# 缓存设置
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 系统优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65536" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65536" >> /etc/sysctl.conf
sudo sysctl -p
```

## 🔐 安全建议

1. **定期更新**
   - 保持NGINX和系统更新
   - 定期更新SSL证书
   - 监控安全漏洞

2. **访问控制**
   - 配置IP白名单（如需要）
   - 使用强密码和密钥认证
   - 限制管理端口访问

3. **监控告警**
   - 设置日志监控
   - 配置异常告警
   - 定期检查访问日志

## 📞 支持

如果遇到问题，请检查：
1. 系统日志：`sudo journalctl -xe`
2. NGINX日志：`/var/log/nginx/`
3. 应用日志：`/home/admin/poly_22_headless/run.log`

---

**注意**: 部署前请确保备份现有配置，并在测试环境中验证所有功能。