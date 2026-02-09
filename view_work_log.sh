#!/bin/bash

# 工作日志查看脚本 - macOS版本

log_file="work_status_log.txt"

# 检查日志文件是否存在
if [ ! -f "$log_file" ]; then
    echo "日志文件不存在：$log_file"
    echo "请先运行健康提醒脚本生成日志记录"
    exit 1
fi

echo "==============================================="
echo "           工作状态日志查看器"
echo "==============================================="
echo "日志文件位置：$log_file"
echo "==============================================="
echo ""

# 提供多种查看选项
echo "请选择查看方式："
echo "1. 查看最近10条记录"
echo "2. 查看今天的记录"
echo "3. 查看全部记录"
echo "4. 搜索特定内容"
echo "5. 统计今天的工作状态"
echo ""

read -p "请输入选项 (1-5): " choice

case $choice in
    1)
        echo "最近10条记录："
        echo "----------------------------------------"
        tail -n 10 "$log_file"
        ;;
    2)
        today=$(date "+%Y-%m-%d")
        echo "今天 ($today) 的记录："
        echo "----------------------------------------"
        grep "^$today" "$log_file" || echo "今天还没有记录"
        ;;
    3)
        echo "全部记录："
        echo "----------------------------------------"
        cat "$log_file"
        ;;
    4)
        read -p "请输入要搜索的关键词: " keyword
        echo "包含 '$keyword' 的记录："
        echo "----------------------------------------"
        grep -i "$keyword" "$log_file" || echo "没有找到包含 '$keyword' 的记录"
        ;;
    5)
        today=$(date "+%Y-%m-%d")
        echo "今天 ($today) 的工作状态统计："
        echo "----------------------------------------"
        if grep -q "^$today" "$log_file"; then
            echo "逐步推进次数: $(grep "^$today.*\[逐步推进，继续执行\]" "$log_file" | wc -l | tr -d ' ')"
            echo "脱离正轨次数: $(grep "^$today.*\[脱离正轨，马上调整\]" "$log_file" | wc -l | tr -d ' ')"
            echo "总记录次数: $(grep "^$today" "$log_file" | wc -l | tr -d ' ')"
        else
            echo "今天还没有记录"
        fi
        ;;
    *)
        echo "无效选项"
        exit 1
        ;;
esac

echo ""
echo "==============================================="
