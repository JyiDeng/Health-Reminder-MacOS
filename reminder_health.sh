#!/bin/bash

# 健康提醒脚本 - macOS版本
# 功能：从配置文件加载任务并定时弹出原生窗口提醒用户
# 依赖：osascript (macOS自带)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/reminder_tasks.conf"
LOG_FILE="$SCRIPT_DIR/work_status_log.txt"
LOCK_DIR="$SCRIPT_DIR/.task_locks"

TASK_NAMES=()
TASK_TYPES=()
TASK_INTERVALS=()
TASK_TITLES=()
TASK_PROMPTS=()
TASK_CHOICES=()

KEYBOARD_MOOD_KEY="a"
CONFIG_MTIME=""

cleanup_stale_locks() {
    [ -d "$LOCK_DIR" ] || return

    # If previous runs exited during a dialog, lock dirs can remain and block tasks forever.
    find "$LOCK_DIR" -mindepth 1 -maxdepth 1 -type d -name '*.lock' -exec rmdir {} + 2>/dev/null || true
}

get_file_mtime() {
    local target="$1"
    stat -f "%m" "$target" 2>/dev/null || echo ""
}

task_lock_key() {
    printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

escape_applescript_string() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

format_choice_list_for_applescript() {
    local choices_raw="$1"
    local result=""
    local choice

    IFS=';' read -r -a parsed_choices <<< "$choices_raw"
    for choice in "${parsed_choices[@]}"; do
        choice="${choice#${choice%%[![:space:]]*}}"
        choice="${choice%${choice##*[![:space:]]}}"
        [ -z "$choice" ] && continue

        if [ -n "$result" ]; then
            result+=", "
        fi
        result+="\"$(escape_applescript_string "$choice")\""
    done

    printf '%s' "$result"
}

is_screen_locked() {
    /usr/sbin/ioreg -n Root -d 1 2>/dev/null | /usr/bin/grep -q '"CGSSessionScreenIsLocked" = Yes'
}

is_user_session_active() {
    local console_user
    console_user=$(/usr/bin/stat -f "%Su" /dev/console 2>/dev/null || echo "")
    [ -n "$console_user" ] && [ "$console_user" != "loginwindow" ]
}

can_present_ui() {
    is_user_session_active && ! is_screen_locked
}

is_seconds_schedule() {
    local schedule="$1"
    [[ "$schedule" =~ ^[0-9]+$ ]]
}

is_cron_schedule() {
    local schedule="$1"
    [[ "$schedule" =~ ^cron: ]]
}

cron_field_matches() {
    local current_value="$1"
    local field_expr="$2"
    local token
    local start
    local end

    [ "$field_expr" = "*" ] && return 0

    IFS=',' read -r -a tokens <<< "$field_expr"
    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^[0-9]+$ ]]; then
            [ "$current_value" -eq "$token" ] && return 0
            continue
        fi

        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"
            if [ "$current_value" -ge "$start" ] && [ "$current_value" -le "$end" ]; then
                return 0
            fi
            continue
        fi

        if [[ "$token" =~ ^\*/([0-9]+)$ ]]; then
            [ "${BASH_REMATCH[1]}" -eq 0 ] && continue
            if (( current_value % BASH_REMATCH[1] == 0 )); then
                return 0
            fi
            continue
        fi
    done

    return 1
}

cron_matches_now() {
    local cron_expr="$1"
    local now_min now_hour now_day now_month now_weekday
    local f_min f_hour f_day f_month f_weekday

    read -r f_min f_hour f_day f_month f_weekday <<< "$cron_expr"
    [ -z "${f_weekday:-}" ] && return 1

    now_min=$(date +"%M")
    now_hour=$(date +"%H")
    now_day=$(date +"%d")
    now_month=$(date +"%m")
    now_weekday=$(date +"%w")

    now_min=$((10#$now_min))
    now_hour=$((10#$now_hour))
    now_day=$((10#$now_day))
    now_month=$((10#$now_month))
    now_weekday=$((10#$now_weekday))

    cron_field_matches "$now_min" "$f_min" || return 1
    cron_field_matches "$now_hour" "$f_hour" || return 1
    cron_field_matches "$now_day" "$f_day" || return 1
    cron_field_matches "$now_month" "$f_month" || return 1
    cron_field_matches "$now_weekday" "$f_weekday" || return 1

    return 0
}

next_sleep_seconds() {
    local current_sec

    current_sec=$(date +"%S")
    current_sec=$((10#$current_sec))

    if [ "$current_sec" -eq 0 ]; then
        echo 60
    else
        echo $((60 - current_sec))
    fi
}

append_log_entry() {
    local status="$1"
    local content="$2"
    local timestamp current_date record_line temp_file

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    current_date=$(date "+%Y-%m-%d")
    record_line="$timestamp [$status] $content"

    if [ -f "$LOG_FILE" ] && grep -q "^$current_date" "$LOG_FILE"; then
        temp_file=$(mktemp)
        {
            echo "$record_line"
            cat "$LOG_FILE"
        } > "$temp_file"
        mv "$temp_file" "$LOG_FILE"
    else
        temp_file=$(mktemp)
        {
            echo "$record_line"
            echo "============================= $current_date  ============================="
            if [ -f "$LOG_FILE" ]; then
                echo ""
                cat "$LOG_FILE"
            fi
        } > "$temp_file"
        mv "$temp_file" "$LOG_FILE"
    fi
}

show_notification() {
    local title="$1"
    local message="$2"

    osascript -e "display notification \"$(escape_applescript_string "$message")\" with title \"$(escape_applescript_string "$title")\"" 2>/dev/null
}

add_mood_record() {
    local timestamp mood_input

    can_present_ui || return

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    mood_input=$(osascript <<EOF
set dialogResult to display dialog "🎭 记录你当前的心情和感受：\n\n格式将为：$timestamp [记录心情，探索动力] 你的输入\n\n请描述你的具体心情：" default answer "" with title "心情记录 📝" buttons {"取消", "确定"} default button "确定"
return text returned of dialogResult
EOF
) 2>/dev/null

    if [ $? -ne 0 ] || [ -z "$mood_input" ]; then
        show_notification "取消记录" "心情记录已取消"
        return
    fi

    append_log_entry "记录心情，探索动力" "$mood_input"
    show_notification "记录完成" "心情记录已成功添加"
}

keyboard_listener() {
    local key
    local mood_key_upper

    mood_key_upper=$(printf '%s' "$KEYBOARD_MOOD_KEY" | tr '[:lower:]' '[:upper:]')
    while true; do
        read -r -n 1 -s key
        if [ "$key" = "$KEYBOARD_MOOD_KEY" ] || [ "$key" = "$mood_key_upper" ]; then
            add_mood_record
        fi
    done
}

run_work_check_task() {
    local title="$1"
    local prompt="$2"
    local choices_raw="$3"
    local choice_list choice timestamp user_input

    can_present_ui || return

    choice_list=$(format_choice_list_for_applescript "$choices_raw")
    [ -z "$choice_list" ] && return

    choice=$(osascript <<EOF
set choiceList to {$choice_list}
set selectedChoice to choose from list choiceList with title "$(escape_applescript_string "$title")" with prompt "$(escape_applescript_string "$prompt")"
if selectedChoice is false then
    return ""
else
    return item 1 of selectedChoice
end if
EOF
) 2>/dev/null

    [ -z "$choice" ] && return

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    user_input=$(osascript <<EOF
set dialogResult to display dialog "请简要描述你当前的工作情况：\n\n格式将为：$timestamp [$choice] 你的输入" default answer "" with title "工作日志记录" buttons {"取消", "确定"} default button "确定"
return text returned of dialogResult
EOF
) 2>/dev/null

    [ $? -ne 0 ] && return

    append_log_entry "$choice" "$user_input"
    show_notification "记录完成" "工作状态已记录到日志"
}

run_info_task() {
    local title="$1"
    local prompt="$2"

    can_present_ui || return

    osascript <<EOF 2>/dev/null
display dialog "$(escape_applescript_string "$prompt")" with title "$(escape_applescript_string "$title")" buttons {"知道了"} default button "知道了"
EOF
}

run_task_loop() {
    local task_name="$1"
    local type="$2"
    local schedule="$3"
    local title="$4"
    local prompt="$5"
    local choices_raw="$6"
    local lock_key lock_path
    local cron_expr=""
    local minute_key=""
    local last_trigger_key=""
    local sleep_seconds

    if is_cron_schedule "$schedule"; then
        cron_expr="${schedule#cron:}"
    fi

    while true; do
        if is_seconds_schedule "$schedule"; then
            sleep "$schedule"
        elif [ -n "$cron_expr" ]; then
            sleep_seconds=$(next_sleep_seconds)
            sleep "$sleep_seconds"

            if ! cron_matches_now "$cron_expr"; then
                continue
            fi

            minute_key=$(date +"%Y-%m-%d %H:%M")
            if [ "$minute_key" = "$last_trigger_key" ]; then
                continue
            fi
            last_trigger_key="$minute_key"
        else
            echo "警告：任务 '$task_name' 的调度格式无效：$schedule" >&2
            sleep 60
            continue
        fi

        lock_key=$(task_lock_key "$task_name")
        lock_path="$LOCK_DIR/${lock_key}.lock"

        # 同一个任务名同一时刻只允许一个弹窗流程。
        if ! mkdir "$lock_path" 2>/dev/null; then
            continue
        fi

        case "$type" in
            work_check)
                run_work_check_task "$title" "$prompt" "$choices_raw"
                ;;
            info)
                run_info_task "$title" "$prompt"
                ;;
            *)
                echo "警告：未知任务类型 '$type'，已跳过" >&2
                ;;
        esac

        rmdir "$lock_path" 2>/dev/null || true
    done
}

load_config() {
    local line
    local name type interval title prompt choices
    local line_no=0
    local names_seen="|"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "错误：未找到配置文件 $CONFIG_FILE" >&2
        exit 1
    fi

    TASK_NAMES=()
    TASK_TYPES=()
    TASK_INTERVALS=()
    TASK_TITLES=()
    TASK_PROMPTS=()
    TASK_CHOICES=()

    while IFS= read -r line || [ -n "$line" ]; do
        line_no=$((line_no + 1))

        [[ -z "$line" || "$line" =~ ^# ]] && continue

        IFS='|' read -r name type interval title prompt choices <<< "$line"

        if [ -z "${name:-}" ] || [ -z "${type:-}" ] || [ -z "${interval:-}" ] || [ -z "${title:-}" ] || [ -z "${prompt:-}" ]; then
            echo "错误：配置文件第 $line_no 行格式不正确" >&2
            exit 1
        fi

        if ! is_seconds_schedule "$interval" && ! is_cron_schedule "$interval"; then
            echo "错误：配置文件第 $line_no 行 schedule 无效：$interval" >&2
            exit 1
        fi

        if is_cron_schedule "$interval"; then
            if ! [[ "$interval" =~ ^cron:[[:space:]]*([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]*$ ]]; then
                echo "错误：配置文件第 $line_no 行 cron 表达式格式应为 cron:分 时 日 月 周" >&2
                exit 1
            fi
        fi

        if [[ "$names_seen" == *"|$name|"* ]]; then
            echo "错误：配置文件第 $line_no 行 name 重复：$name" >&2
            exit 1
        fi
        names_seen+="$name|"

        TASK_NAMES+=("$name")
        TASK_TYPES+=("$type")
        TASK_INTERVALS+=("$interval")
        TASK_TITLES+=("$title")
        TASK_PROMPTS+=("${prompt//\\n/$'\n'}")
        TASK_CHOICES+=("${choices:-}")
    done < "$CONFIG_FILE"

    if [ ${#TASK_NAMES[@]} -eq 0 ]; then
        echo "错误：配置文件中没有可用任务" >&2
        exit 1
    fi

    CONFIG_MTIME=$(get_file_mtime "$CONFIG_FILE")
}

config_watcher() {
    local parent_pid="$1"
    local initial_mtime="$2"
    local current_mtime

    while true; do
        sleep 5
        current_mtime=$(get_file_mtime "$CONFIG_FILE")

        if [ -z "$current_mtime" ]; then
            continue
        fi

        if [ "$current_mtime" != "$initial_mtime" ]; then
            kill -HUP "$parent_pid" 2>/dev/null || true
            exit 0
        fi
    done
}

print_startup_info() {
    local i
    echo "启动健康提醒系统..."
    echo "当前已加载任务："

    for i in "${!TASK_NAMES[@]}"; do
        echo "$((i + 1)). ${TASK_NAMES[$i]} (${TASK_INTERVALS[$i]}秒)"
    done

    if [ -t 0 ]; then
        echo ""
        echo "按 '$KEYBOARD_MOOD_KEY' 添加心情记录，按 Ctrl+C 停止程序"
    else
        echo ""
        echo "当前为非交互模式（例如 launchd），已禁用键盘快捷记录"
    fi
}

cleanup() {
    local job_pids

    echo ""
    echo "正在停止所有提醒..."
    job_pids=$(jobs -p)

    if [ -n "$job_pids" ]; then
        echo "$job_pids" | xargs kill 2>/dev/null
        sleep 1
        echo "$job_pids" | xargs kill -9 2>/dev/null
    fi

    echo "健康提醒系统已停止"
    exit 0
}

reload_and_restart() {
    local job_pids

    echo ""
    echo "检测到配置文件变更，正在自动重载..."

    # 先结束现有子任务，避免重复提醒。
    job_pids=$(jobs -p)
    if [ -n "$job_pids" ]; then
        echo "$job_pids" | xargs kill 2>/dev/null
        sleep 1
    fi

    cleanup_stale_locks

    exec /bin/bash "$0"
}

main() {
    local i

    load_config
    mkdir -p "$LOCK_DIR"
    cleanup_stale_locks
    print_startup_info

    for i in "${!TASK_NAMES[@]}"; do
        run_task_loop "${TASK_NAMES[$i]}" "${TASK_TYPES[$i]}" "${TASK_INTERVALS[$i]}" "${TASK_TITLES[$i]}" "${TASK_PROMPTS[$i]}" "${TASK_CHOICES[$i]}" &
    done

    if [ -t 0 ]; then
        keyboard_listener &
    fi

    config_watcher "$$" "$CONFIG_MTIME" &

    wait
}

trap cleanup SIGINT SIGTERM
trap reload_and_restart SIGHUP

main
