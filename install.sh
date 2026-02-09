#!/bin/bash

# macOS健康提醒系统安装脚本

echo "🏥 macOS健康提醒系统安装程序"
echo "=================================="

# 检查是否为macOS系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 错误：此脚本仅支持macOS系统"
    exit 1
fi

echo "✅ 检测到macOS系统"
echo "💡 macOS使用osascript作为原生对话框工具（系统自带，无需安装）"
echo ""

# 添加执行权限
echo "🔧 设置脚本执行权限..."
chmod +x reminder_health.sh view_work_log.sh

echo ""
echo "🎉 安装完成！"
echo ""
echo "使用方法："
echo "  启动健康提醒系统: ./reminder_health.sh"
echo "  查看工作日志:     ./view_work_log.sh"
echo ""
echo "💡 提示："
echo "  - 可以将reminder_health.sh添加到登录项实现开机自启动"
echo "  - 在终端中运行，保持终端窗口打开以便使用 'a' 键记录心情"
echo "  - 首次运行时macOS可能会询问辅助功能权限，请允许访问"
echo ""
echo "🔐 设置开机自启动（可选）："
echo "  1. 打开 系统设置 > 通用 > 登录项"
echo "  2. 点击 '+' 添加 reminder_health.sh"
echo "  3. 或使用命令："
echo "     osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"$(pwd)/reminder_health.sh\", hidden:false}'"
