#!/bin/bash

# macOS健康提醒系统安装脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_LABEL="com.$(id -un).health-reminder"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/$LAUNCH_AGENT_LABEL.plist"

create_launch_agent_plist() {
    mkdir -p "$LAUNCH_AGENT_DIR"

    cat > "$LAUNCH_AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCH_AGENT_LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/reminder_health.sh</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/launchd_stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/launchd_stderr.log</string>
</dict>
</plist>
EOF
}

load_launch_agent() {
    launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PLIST"
    launchctl enable "gui/$(id -u)/$LAUNCH_AGENT_LABEL"
}

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
chmod +x "$SCRIPT_DIR/reminder_health.sh" "$SCRIPT_DIR/view_work_log.sh" "$SCRIPT_DIR/open_dashboard.sh" "$SCRIPT_DIR/restart.sh"

if [ ! -f "$SCRIPT_DIR/reminder_tasks.conf" ]; then
    echo "❌ 缺少配置文件：$SCRIPT_DIR/reminder_tasks.conf"
    exit 1
fi

echo "🚀 配置开机自启动（LaunchAgent）..."
create_launch_agent_plist
load_launch_agent

echo ""
echo "🎉 安装完成！"
echo ""
echo "使用方法："
echo "  启动健康提醒系统: $SCRIPT_DIR/reminder_health.sh"
echo "  查看工作日志:     $SCRIPT_DIR/view_work_log.sh"
echo "  打开数据看板:     $SCRIPT_DIR/open_dashboard.sh"
echo "  任务配置文件:      $SCRIPT_DIR/reminder_tasks.conf"
echo ""
echo "💡 提示："
echo "  - 已配置登录后自动启动（LaunchAgent）"
echo "  - 手动运行时可按 'a' 键记录心情，LaunchAgent模式不支持按键输入"
echo "  - 首次运行时macOS可能会询问辅助功能权限，请允许访问"
echo ""
echo "🔐 LaunchAgent信息："
echo "  - Label:      $LAUNCH_AGENT_LABEL"
echo "  - Plist路径:  $LAUNCH_AGENT_PLIST"
echo "  - 标准输出:   $SCRIPT_DIR/launchd_stdout.log"
echo "  - 错误输出:   $SCRIPT_DIR/launchd_stderr.log"
echo ""
echo "🧹 如需移除开机自启动："
echo "  launchctl bootout gui/$(id -u) $LAUNCH_AGENT_PLIST"
echo "  rm -f $LAUNCH_AGENT_PLIST"
