# Deploy Ubuntu 脚本集成 NGINX 反向代理更新说明

## 更新概述

已将 `setup_nginx.sh` 的 NGINX 反向代理功能完全集成到 `deploy_ubuntu.sh` 脚本中，实现真正的一键部署。

## 主要变更

### 1. 新增 NGINX 配置选项
- 在部署过程中询问用户是否配置 NGINX 反向代理
- 提供推荐提示，说明可避免端口直接暴露的安全优势
- 支持可选的 SSL 证书配置（Let's Encrypt）

### 2. 智能化服务配置
- **启用 NGINX 时**：
  - Flask 应用绑定到 `127.0.0.1:5000`（仅本地访问）
  - systemd 服务依赖 nginx.service
  - 通过端口 80/443 访问（经 NGINX 代理）
  - 增强的安全设置和资源限制

- **不启用 NGINX 时**：
  - Flask 应用绑定到 `0.0.0.0:5000`（所有接口）
  - 直接通过端口 5000 访问
  - 配置防火墙规则开放端口 5000

### 3. 自动化 NGINX 配置
- 自动安装 NGINX
- 创建优化的反向代理配置文件
- 包含安全头、WebSocket 支持、静态文件缓存
- 自动备份原始配置
- 配置访问和错误日志

### 4. SSL 证书支持
- 可选的 Let's Encrypt SSL 证书配置
- 自动设置证书续期任务
- 支持 HTTPS 访问

### 5. 防火墙智能配置
- 启用 NGINX 时：配置端口 80/443
- 不启用 NGINX 时：配置端口 5000
- 自动检测并配置 UFW 防火墙

### 6. 启动脚本优化
- 根据配置自动设置 Flask 环境变量
- 简化启动流程，移除不必要的 Chrome 手动管理
- 支持生产环境配置

## 部署流程

### 标准部署（推荐）
```bash
./deploy_ubuntu.sh
```

部署过程中的选择：
1. **NGINX 反向代理**：选择 `y`（推荐）
2. **SSL 证书**：如有域名选择 `y`，否则选择 `n`
3. **systemd 服务**：选择 `y`（推荐）
4. **立即启动**：选择 `y` 进行测试

### 部署架构对比

#### 使用 NGINX（推荐）
```
互联网 → NGINX (80/443) → Flask (127.0.0.1:5000)
```
- ✅ 端口不直接暴露
- ✅ SSL 终端处理
- ✅ 静态文件缓存
- ✅ 安全头保护
- ✅ 负载均衡能力

#### 直接访问
```
互联网 → Flask (0.0.0.0:5000)
```
- ⚠️ 端口直接暴露
- ⚠️ 无 SSL 终端
- ⚠️ 无缓存优化
- ⚠️ 基础安全保护

## 配置文件说明

### NGINX 配置特性
- **反向代理**：所有请求转发到 Flask 应用
- **安全头**：X-Frame-Options、CSP 等安全头
- **WebSocket 支持**：完整的 WebSocket 代理配置
- **静态文件缓存**：1年缓存期，提升性能
- **超时设置**：60秒连接、发送、读取超时
- **日志记录**：独立的访问和错误日志

### systemd 服务增强
- **安全限制**：NoNewPrivileges、PrivateTmp 等
- **资源限制**：文件描述符和进程数限制
- **环境变量**：Flask 主机、端口、环境配置
- **依赖管理**：NGINX 服务依赖关系

## 管理命令

### 服务管理
```bash
# 启动服务
sudo systemctl start crypto-trader

# 停止服务
sudo systemctl stop crypto-trader

# 查看状态
sudo systemctl status crypto-trader

# 查看日志
sudo journalctl -u crypto-trader -f
```

### NGINX 管理
```bash
# 重启 NGINX
sudo systemctl restart nginx

# 测试配置
sudo nginx -t

# 查看访问日志
sudo tail -f /var/log/nginx/crypto-trader.access.log

# 查看错误日志
sudo tail -f /var/log/nginx/crypto-trader.error.log
```

## 安全优势

1. **端口隐藏**：Flask 应用不直接暴露在公网
2. **SSL 终端**：NGINX 处理 SSL 加密/解密
3. **安全头**：自动添加多种安全响应头
4. **访问控制**：可在 NGINX 层面添加访问限制
5. **DDoS 防护**：NGINX 提供基础的 DDoS 防护

## 性能优化

1. **静态文件缓存**：CSS、JS、图片等静态资源缓存
2. **连接复用**：HTTP/1.1 连接复用
3. **压缩传输**：可配置 gzip 压缩
4. **负载均衡**：支持多实例负载均衡

## 故障排除

### 常见问题

1. **NGINX 配置测试失败**
   ```bash
   sudo nginx -t
   # 检查配置文件语法
   ```

2. **端口冲突**
   ```bash
   sudo netstat -tlnp | grep :80
   # 检查端口占用情况
   ```

3. **SSL 证书问题**
   ```bash
   sudo certbot certificates
   # 查看证书状态
   ```

4. **服务启动失败**
   ```bash
   sudo journalctl -u crypto-trader -n 50
   # 查看详细错误日志
   ```

## 升级说明

### 从旧版本升级
如果已使用旧版本的 `deploy_ubuntu.sh`，建议：

1. 备份现有配置
2. 停止现有服务
3. 运行新版本部署脚本
4. 选择启用 NGINX 反向代理
5. 验证服务正常运行

### 配置迁移
- 旧的 systemd 服务配置会被新配置替换
- Flask 应用会自动适配新的环境变量
- 无需手动修改应用代码

## 总结

通过集成 NGINX 反向代理功能，`deploy_ubuntu.sh` 现在提供：

- ✅ **一键部署**：单个脚本完成所有配置
- ✅ **安全增强**：NGINX 反向代理保护
- ✅ **性能优化**：静态文件缓存和连接优化
- ✅ **SSL 支持**：可选的 HTTPS 配置
- ✅ **智能配置**：根据选择自动调整配置
- ✅ **生产就绪**：适合生产环境部署

这个更新使得 Crypto Trader 应用的部署更加简单、安全和高效。