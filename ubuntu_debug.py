#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ubuntu服务器日志问题诊断脚本
用于检查Ubuntu服务器上crypto_trader.py的实际运行状态和日志配置
"""

import os
import sys
import glob
from datetime import datetime

def main():
    print("Ubuntu服务器日志问题诊断")
    print("=" * 50)
    print(f"诊断时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"当前工作目录: {os.getcwd()}")
    print(f"Python版本: {sys.version}")
    print()
    
    # 1. 检查环境变量和路径
    print("=== 1. 环境检查 ===")
    home_dir = os.path.expanduser("~")
    print(f"用户主目录: {home_dir}")
    print(f"$HOME环境变量: {os.environ.get('HOME', '未设置')}")
    print()
    
    # 2. 检查日志目录
    print("=== 2. 日志目录检查 ===")
    poly_log_dir = os.path.join(home_dir, "poly_16", "logs")
    local_log_dir = "logs"
    
    print(f"预期日志目录: {poly_log_dir}")
    print(f"目录是否存在: {os.path.exists(poly_log_dir)}")
    
    if os.path.exists(poly_log_dir):
        try:
            log_files = glob.glob(os.path.join(poly_log_dir, "????????.log"))
            print(f"✅ 找到 {len(log_files)} 个日志文件")
            if log_files:
                latest_log = max(log_files)
                print(f"最新日志: {latest_log}")
                
                # 读取最新日志的最后几行
                try:
                    with open(latest_log, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                        if lines:
                            print(f"日志文件行数: {len(lines)}")
                            print("最后3行内容:")
                            for line in lines[-3:]:
                                print(f"  {line.strip()}")
                        else:
                            print("⚠️  日志文件为空")
                except Exception as e:
                    print(f"❌ 读取日志文件失败: {e}")
        except Exception as e:
            print(f"❌ 检查日志文件失败: {e}")
    else:
        print(f"❌ 预期日志目录不存在")
    
    # 检查本地logs目录
    print(f"\n本地logs目录: {os.path.abspath(local_log_dir)}")
    print(f"目录是否存在: {os.path.exists(local_log_dir)}")
    
    if os.path.exists(local_log_dir):
        try:
            local_log_files = glob.glob(os.path.join(local_log_dir, "*.log"))
            print(f"⚠️  本地logs目录存在，包含 {len(local_log_files)} 个文件")
            if local_log_files:
                for log_file in local_log_files[-3:]:  # 显示最后3个文件
                    print(f"  文件: {log_file}")
        except Exception as e:
            print(f"❌ 检查本地logs目录失败: {e}")
    print()
    
    # 3. 测试Logger类配置
    print("=== 3. 测试Logger类配置 ===")
    try:
        # 导入并测试Logger类
        sys.path.insert(0, os.getcwd())
        
        # 检查crypto_trader.py文件是否存在
        if os.path.exists('crypto_trader.py'):
            print("✅ crypto_trader.py 文件存在")
            
            # 尝试导入Logger类
            try:
                # 读取文件内容检查Logger类配置
                with open('crypto_trader.py', 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                if 'poly_16/logs' in content:
                    print("✅ crypto_trader.py 中包含 poly_16/logs 路径配置")
                else:
                    print("❌ crypto_trader.py 中未找到 poly_16/logs 路径配置")
                    
                if 'logs/' in content and 'poly_16' not in content:
                    print("⚠️  crypto_trader.py 中仍包含本地 logs/ 路径")
                    
            except Exception as e:
                print(f"❌ 读取crypto_trader.py失败: {e}")
        else:
            print("❌ crypto_trader.py 文件不存在")
            
    except Exception as e:
        print(f"❌ 测试Logger类失败: {e}")
    print()
    
    # 4. 检查运行中的进程
    print("=== 4. 进程检查 ===")
    print("请手动运行以下命令检查当前运行的进程:")
    print("ps aux | grep crypto_trader")
    print("ps aux | grep python")
    print()
    
    # 5. 系统服务检查
    print("=== 5. 系统服务检查 ===")
    print("请手动运行以下命令检查系统服务:")
    print("systemctl status run-poly.service")
    print("systemctl status run-poly@$(whoami).service")
    print("journalctl -u run-poly@$(whoami).service -n 20")
    print()
    
    # 6. 解决方案建议
    print("=== 6. 解决方案建议 ===")
    if not os.path.exists(poly_log_dir):
        print("🔧 建议操作:")
        print("1. 手动创建日志目录:")
        print(f"   mkdir -p {poly_log_dir}")
        print("2. 重启服务:")
        print("   sudo systemctl restart run-poly@$(whoami).service")
    else:
        print("🔧 建议操作:")
        print("1. 停止当前服务:")
        print("   sudo systemctl stop run-poly@$(whoami).service")
        print("2. 确保使用最新代码版本")
        print("3. 重新启动服务:")
        print("   sudo systemctl start run-poly@$(whoami).service")
        print("4. 检查服务状态:")
        print("   sudo systemctl status run-poly@$(whoami).service")
        print("5. 查看实时日志:")
        print(f"   tail -f {poly_log_dir}/$(date +%Y%m%d).log")
    
    print("\n诊断完成！")

if __name__ == "__main__":
    main()