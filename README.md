# macOS Health Reminder

一个基于 osascript 的 macOS 健康提醒系统，帮助你在工作过程中持续记录状态、按节奏休息，并用网页看板复盘趋势。

## 主要能力

- 定时提醒：支持秒级间隔和 cron 表达式两种调度
- 工作检查：通过原生对话框记录当前工作状态和说明
- 心情记录：运行期间按 `a` 可快速写入想法或情绪
- 自动日志：按时间倒序写入 `work_status_log.txt`
- 数据看板：自动汇总日志和任务配置，展示趋势与统计
- 配置热更新：修改 `reminder_tasks.conf` 后自动重载

## 项目结构

```text
.
├── install.sh                  # 安装并配置 LaunchAgent
├── reminder_health.sh          # 主提醒脚本
├── reminder_tasks.conf         # 提醒任务配置
├── restart.sh                  # 重启 LaunchAgent 并查看日志
├── view_work_log.sh            # 日志查看工具
├── open_dashboard.sh           # 生成并打开网页看板
├── work_status_log.txt         # 工作日志
├── dashboard/                  # 前端看板
└── scripts/build_dashboard_data.py
```

## 环境要求

- macOS 10.10+
- Bash（系统自带）
- osascript（系统自带）
- Python 3（用于构建 dashboard 数据）

## 快速开始

```bash
git clone https://github.com/yourusername/Health-Reminder-MacOS.git
cd Health-Reminder-MacOS

# 安装：设置执行权限 + 配置开机自启动
./install.sh

# 前台运行提醒（支持按 a 快速记录心情）
./reminder_health.sh
```

## 常用命令

```bash
# 查看日志
./view_work_log.sh

# 打开网页看板
./open_dashboard.sh

# 重启 LaunchAgent 并查看最近输出
./restart.sh
```

## 配置说明

所有提醒任务定义在 `reminder_tasks.conf`：

```text
name|type|schedule|title|prompt|choices(optional)
```

字段说明：

1. `name`：任务名称（用于终端展示）
2. `type`：任务类型，支持 `work_check` 和 `info`
3. `schedule`：调度表达式
4. `title`：弹窗标题
5. `prompt`：弹窗内容（支持 `\n` 换行）
6. `choices(optional)`：`work_check` 任务的选项，分号分隔

调度示例：

- 秒级间隔：`1800`
- cron：`cron:0 7 * * *`

配置示例：

```text
stretch|info|1800|拉伸提醒|到时间啦，起来拉伸一下！|
morning-water|info|cron:0 7 * * *|喝水提醒|早上空腹喝一杯水！|
focus-check|work_check|1500|专注检查|你现在的状态如何？|继续专注;偏离任务
```

## LaunchAgent 说明

`install.sh` 会自动生成并加载 LaunchAgent。Label 会根据当前系统用户名动态生成，不依赖固定用户名。

查看当前 Label 与 plist 路径：

```bash
LAUNCH_AGENT_LABEL="com.$(id -un).health-reminder"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_LABEL.plist"
echo "$LAUNCH_AGENT_LABEL"
echo "$LAUNCH_AGENT_PLIST"
```

手动移除开机自启动：

```bash
LAUNCH_AGENT_LABEL="com.$(id -un).health-reminder"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_LABEL.plist"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST"
rm -f "$LAUNCH_AGENT_PLIST"
```

## 日志格式

日志写入 `work_status_log.txt`，典型格式：

```text
2026-02-09 14:30:45 [逐步推进，继续执行] 完成了数据分析模块开发
2026-02-09 14:05:20 [脱离正轨，马上调整] 被社交媒体分散注意力，已重新聚焦
============================= 2026-02-09  =============================
```

## 常见问题

Q: 没有弹出提醒对话框？

A: 请在 macOS `系统设置 -> 隐私与安全性 -> 辅助功能` 中允许终端应用。

Q: 后台运行可以按 `a` 记录心情吗？

A: 不可以。按键监听仅在前台终端运行 `./reminder_health.sh` 时可用。

Q: 配置修改后要重启吗？

A: 一般不需要，脚本会自动检测 `reminder_tasks.conf` 变更并重载。

## 建议使用方式

1. 每天结束前回顾日志，识别高频分心场景
2. 先保持默认间隔一周，再按节奏微调
3. 将关键主题写入记录内容，便于看板聚合分析

## License

MIT

## Credits

改编自 Zenity-Health-Reminder-Ubuntu，并针对 macOS 进行了重构与增强。
