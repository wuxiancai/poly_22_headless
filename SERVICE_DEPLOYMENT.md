# Systemd 服务部署说明

## 概述

本项目使用 `run-poly@.service` 模板服务，支持在任何用户名的 Ubuntu 系统上运行，无需修改配置文件中的用户名和路径。

## 服务特性

- **动态用户支持**: 使用 systemd 的 `%i` 和 `%h` 占位符自动适配不同用户
- **路径自适应**: 自动使用用户家目录下的 `poly_22_headless` 项目路径
- **虚拟环境支持**: 自动使用项目中的 Python 虚拟环境

## 占位符说明

- `%i`: 服务实例名称（用户名）
- `%h`: 用户家目录路径

## 部署方式

### 自动部署（推荐）

运行部署脚本：
```bash
./deploy_ubuntu.sh
```

脚本会自动：
1. 检测当前用户名
2. 复制 `run-poly.service` 模板到系统目录
3. 创建用户特定的服务实例
4. 启用服务自启动

### 手动部署

1. 复制服务模板文件：
```bash
sudo cp run-poly.service /etc/systemd/system/run-poly@.service
```

2. 重新加载 systemd 配置：
```bash
sudo systemctl daemon-reload
```

3. 启用服务（替换 `username` 为实际用户名）：
```bash
sudo systemctl enable run-poly@username.service
```

## 服务管理命令

### 对于用户 `admin`：
```bash
# 启动服务
sudo systemctl start run-poly@admin.service

# 停止服务
sudo systemctl stop run-poly@admin.service

# 重启服务
sudo systemctl restart run-poly@admin.service

# 查看状态
sudo systemctl status run-poly@admin.service

# 查看日志
sudo journalctl -u run-poly@admin.service -f

# 启用开机自启
sudo systemctl enable run-poly@admin.service

# 禁用开机自启
sudo systemctl disable run-poly@admin.service
```

### 对于用户 `ubuntu`：
```bash
# 启动服务
sudo systemctl start run-poly@ubuntu.service

# 停止服务
sudo systemctl stop run-poly@ubuntu.service

# 重启服务
sudo systemctl restart run-poly@ubuntu.service

# 查看状态
sudo systemctl status run-poly@ubuntu.service

# 查看日志
sudo journalctl -u run-poly@ubuntu.service -f
```

## 目录结构要求

服务要求项目位于用户家目录下的 `poly_22_headless` 文件夹中：

```
/home/username/poly_22_headless/
├── crypto_trader.py          # 主程序
├── venv/                     # Python 虚拟环境
├── run-poly.service          # 服务模板文件
└── deploy_ubuntu.sh          # 部署脚本
```

## 环境变量

服务会自动设置以下环境变量：
- `PATH`: 包含虚拟环境的 Python 路径
- `FLASK_HOST`: Flask 服务绑定地址
- `FLASK_PORT`: Flask 服务端口（5000）
- `FLASK_ENV`: Flask 运行环境（production）

## 安全设置

服务包含以下安全配置：
- `NoNewPrivileges=yes`: 禁止获取新权限
- `PrivateTmp=yes`: 使用私有临时目录
- `ProtectSystem=strict`: 严格保护系统目录
- `ProtectHome=yes`: 保护其他用户家目录
- `ReadWritePaths`: 仅允许读写项目目录

## 故障排除

### 服务启动失败

1. 检查服务状态：
```bash
sudo systemctl status run-poly@username.service
```

2. 查看详细日志：
```bash
sudo journalctl -u run-poly@username.service -n 50
```

3. 检查项目路径是否正确：
```bash
ls -la /home/username/poly_22_headless/
```

4. 检查虚拟环境是否存在：
```bash
ls -la /home/username/poly_22_headless/venv/bin/python
```

### 权限问题

确保用户对项目目录有完整权限：
```bash
sudo chown -R username:username /home/username/poly_22_headless/
sudo chmod -R 755 /home/username/poly_22_headless/
```

## Web 界面重启功能

程序的 Web 界面中的重启功能会自动检测当前用户名，并使用正确的服务名称进行重启操作。