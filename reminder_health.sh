#!/bin/bash

# 健康提醒脚本 - macOS版本
# 功能：定时弹出原生窗口提醒用户
# 依赖：osascript (macOS自带)

# 添加心情记录的函数（使用osascript弹窗）
add_mood_record() {
    # 创建日志文件路径（在脚本当前目录）
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    log_file="$script_dir/work_status_log.txt"
    
    # 获取当前时间戳
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # 使用osascript弹出输入框让用户填写心情内容
    mood_input=$(osascript <<EOF
tell application "System Events"
    activate
    set dialogResult to display dialog "🎭 记录你当前的心情和感受：

格式将为：$timestamp [记录心情，探索动力] 你的输入

请描述你的具体心情：" default answer "" with title "心情记录 📝" buttons {"取消", "确定"} default button "确定"
    return text returned of dialogResult
end tell
EOF
)
    
    # 如果用户取消了输入框，跳过此次记录
    if [ $? -ne 0 ] || [ -z "$mood_input" ]; then
        osascript -e 'display notification "❌ 心情记录已取消" with title "取消记录"'
        return
    fi
    
    # 获取当前日期
    current_date=$(date "+%Y-%m-%d")
    
    # 构造记录条目
    record_line="$timestamp [记录心情，探索动力] $mood_input"
    
    # 检查日志文件中是否已存在今天的日期
    if [ -f "$log_file" ] && grep -q "^$current_date" "$log_file"; then
        # 如果已存在今天的记录，直接插入到文件开头
        temp_file=$(mktemp)
        echo "$record_line" > "$temp_file"
        cat "$log_file" >> "$temp_file"
        mv "$temp_file" "$log_file"
    else
        # 如果是新日期，需要添加日期分割线
        temp_file=$(mktemp)
        echo "$record_line" >> "$temp_file"
        echo "============================= $current_date  =============================" >> "$temp_file"
        
        # 如果日志文件存在，将旧内容追加到新内容后面
        if [ -f "$log_file" ]; then
            echo "" >> "$temp_file"  # 添加空行分隔
            cat "$log_file" >> "$temp_file"
        fi
        mv "$temp_file" "$log_file"
    fi
    
    # 使用osascript显示确认消息
    osascript -e "display notification \"🎭 心情记录已成功添加！

记录内容：
$record_line

日志位置：$log_file\" with title \"记录完成 ✅\""
}

# 监听键盘输入的后台函数
keyboard_listener() {
    while true; do
        # 读取单个字符输入
        read -n 1 -s key
        if [ "$key" = "a" ] || [ "$key" = "A" ]; then
            # 直接调用心情记录函数（使用osascript弹窗）
            add_mood_record
        fi
    done
}

# 模块1：每25分钟提醒确认当前工作（带日志记录）
work_check_reminder() {
    # 创建日志文件路径（在脚本当前目录）
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    log_file="$script_dir/work_status_log.txt"
    
    while true; do
        sleep 1500  # 25分钟 = 1500秒
        
        # 显示选择对话框
        choice=$(osascript <<EOF
tell application "System Events"
    activate
    set choiceList to {"逐步推进，继续执行", "脱离正轨，马上调整"}
    set selectedChoice to choose from list choiceList with title "工作状态确认" with prompt "⏰ 25分钟提醒

请选择你当前的工作状态："
    if selectedChoice is false then
        return ""
    else
        return item 1 of selectedChoice
    end if
end tell
EOF
)
        
        # 如果用户取消了对话框，跳过此次记录
        if [ -z "$choice" ]; then
            continue
        fi
        
        # 获取当前时间戳
        timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        
        # 显示输入框让用户填写具体内容
        user_input=$(osascript <<EOF
tell application "System Events"
    activate
    set dialogResult to display dialog "请简要描述你当前的工作情况：

格式将为：$timestamp [$choice] 你的输入" default answer "" with title "工作日志记录" buttons {"取消", "确定"} default button "确定"
    return text returned of dialogResult
end tell
EOF
)
        
        # 如果用户取消了输入框，跳过此次记录
        if [ $? -ne 0 ]; then
            continue
        fi
        
        # 获取当前时间戳和日期
        timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        current_date=$(date "+%Y-%m-%d")
        
        # 检查日志文件中是否已存在今天的日期
        if [ -f "$log_file" ] && grep -q "^$current_date" "$log_file"; then
            # 如果已存在今天的记录，直接插入到文件开头
            temp_file=$(mktemp)
            echo "$timestamp [$choice] $user_input" > "$temp_file"
            cat "$log_file" >> "$temp_file"
            mv "$temp_file" "$log_file"
        else
            # 如果是新日期，需要添加日期分割线
            temp_file=$(mktemp)
            echo "$timestamp [$choice] $user_input" >> "$temp_file"
            echo "============================= $current_date  =============================" >> "$temp_file"
            
            # 如果日志文件存在，将旧内容追加到新内容后面
            if [ -f "$log_file" ]; then
                echo "" >> "$temp_file"  # 添加空行分隔
                cat "$log_file" >> "$temp_file"
            fi
            mv "$temp_file" "$log_file"
        fi
        
        # 显示确认消息
        osascript -e "display notification \"✅ 工作状态已记录到日志

日志位置：$log_file\" with title \"记录完成\""
    done
}

# 模块2：每37分钟提醒站立活动和喝水
activity_reminder() {
    while true; do
        sleep 2220  # 37分钟 = 2220秒
        osascript <<EOF
tell application "System Events"
    activate
    display dialog "🚶‍♂️ 37分钟提醒

是时候站起来活动一下了！

建议：
• 站立伸展2-3分钟
• 喝一杯水
• 眺望远方放松眼睛" with title "健康活动提醒" buttons {"知道了"} default button "知道了"
end tell
EOF
    done
}

# 模块3：每53分钟提醒上厕所
bathroom_reminder() {
    while true; do
        sleep 3180  # 53分钟 = 3180秒
        osascript <<EOF
tell application "System Events"
    activate
    display dialog "🚽 53分钟提醒

该去趟洗手间了！

这也是一个很好的休息机会：
• 放松身心
• 活动一下腿脚
• 洗洗手保持卫生" with title "生理需求提醒" buttons {"知道了"} default button "知道了"
end tell
EOF
    done
}

# 主函数
main() {
    echo "启动健康提醒系统..."
    echo "包含四个功能模块："
    echo "1. 工作确认提醒 (每25分钟)"
    echo "2. 活动喝水提醒 (每37分钟)"
    echo "3. 上厕所提醒 (每53分钟)"
    echo "4. 心情记录功能 (按 'a' 键添加)"
    echo ""
    echo "按 'a' 添加心情记录，按 Ctrl+C 停止程序"
    
    # 后台启动四个模块
    work_check_reminder &
    activity_reminder &
    bathroom_reminder &
    keyboard_listener &
    
    # 等待用户中断
    wait
}

# 信号处理：优雅退出
cleanup() {
    echo ""
    echo "正在停止所有提醒..."
    
    # 获取所有后台job的PID
    job_pids=$(jobs -p)
    
    if [ -n "$job_pids" ]; then
        # 只有当存在后台进程时才执行kill命令
        echo "$job_pids" | xargs kill 2>/dev/null
        # 等待进程结束
        sleep 1
        # 强制杀死仍在运行的进程
        echo "$job_pids" | xargs kill -9 2>/dev/null
    fi
    
    echo "健康提醒系统已停止"
    exit 0
}

# 捕获中断信号
trap cleanup SIGINT SIGTERM

# 启动主程序
main
