# 🏥 macOS健康提醒系统

一个基于osascript的macOS桌面健康提醒工具，帮助提高工作效率和保持健康的工作习惯。

## ✨ 功能特性

### 🔔 智能提醒系统
- **工作状态确认** (每25分钟)：确认当前工作方向是否正确，并记录工作日志
- **活动喝水提醒** (每37分钟)：提醒站立活动和补充水分
- **生理需求提醒** (每53分钟)：提醒上厕所，保持健康作息

### 📝 工作日志记录
- 自动记录工作状态和进展
- 支持两种状态分类：`逐步推进，继续执行` 和 `脱离正轨，马上调整`
- 时间戳格式：`2026-02-09 09:48:01 [状态] 具体描述`
- 日志按日期分组显示，便于回顾

### 📊 日志查看工具
- 查看最近10条记录
- 按日期筛选记录
- 关键词搜索功能
- 工作状态统计分析

### 💭 心情记录功能
- 随时按 'a' 键快速记录心情和想法
- 使用原生对话框输入，简洁方便
- 统一格式：`[记录心情，探索动力] 你的心情描述`

## 🚀 快速开始

### 系统要求
- macOS 10.10+ (osascript是macOS系统自带工具)
- 终端应用 (Terminal或iTerm2等)

### 安装使用

```bash
# 克隆仓库
git clone https://github.com/yourusername/Health-Reminder-MacOS.git
cd Health-Reminder-MacOS

# 运行安装脚本（会自动设置执行权限）
./install.sh

# 或手动添加执行权限
chmod +x reminder_health.sh view_work_log.sh

# 启动健康提醒系统
./reminder_health.sh
```

## 📖 使用说明

### 启动提醒系统

```bash
./reminder_health.sh
```

启动后会在终端显示以下信息：
```
启动健康提醒系统...
包含四个功能模块：
1. 工作确认提醒 (每25分钟)
2. 活动喝水提醒 (每37分钟)
3. 上厕所提醒 (每53分钟)
4. 心情记录功能 (按 'a' 键添加)

按 'a' 添加心情记录，按 Ctrl+C 停止程序
```

**注意事项：**
- 首次运行时，macOS可能会询问辅助功能权限，请允许Terminal访问
- 保持终端窗口打开（可最小化），以便系统正常工作和使用 'a' 键记录心情
- 按 `Ctrl+C` 可以优雅地停止所有提醒

### 查看工作日志

```bash
./view_work_log.sh
```

提供以下查看选项：
1. **查看最近10条记录** - 快速浏览最新的工作状态
2. **查看今天的记录** - 回顾今天的所有记录
3. **查看全部记录** - 查看完整的工作日志
4. **搜索特定内容** - 使用关键词搜索相关记录
5. **统计今天的工作状态** - 分析今天的工作效率

### 心情记录功能

在提醒系统运行期间，随时按 `a` 键可以快速记录心情：
- 会弹出原生输入对话框
- 输入你的心情描述，点击"确定"即可保存
- 记录会自动添加时间戳和标签 `[记录心情，探索动力]`
- 可用于记录灵感、情绪变化、想法等

## 💡 进阶使用

### 设置开机自启动

**方法1：使用系统设置（推荐）**
1. 打开 `系统设置` > `通用` > `登录项`
2. 点击 `+` 添加应用程序
3. 找到并选择 `reminder_health.sh` 脚本

**方法2：使用命令行**
```bash
# 在Health-Reminder-MacOS目录下运行
osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$(pwd)/reminder_health.sh\", hidden:false}"
```

**方法3：使用launchd（高级）**
创建 `~/Library/LaunchAgents/com.user.health-reminder.plist` 文件：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.health-reminder</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/Health-Reminder-MacOS/reminder_health.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

然后加载：
```bash
launchctl load ~/Library/LaunchAgents/com.user.health-reminder.plist
```

### 自定义提醒间隔

编辑 `reminder_health.sh` 文件，修改以下行：
- 工作确认：`sleep 1500` (默认25分钟 = 1500秒)
- 活动喝水：`sleep 2220` (默认37分钟 = 2220秒)
- 上厕所：`sleep 3180` (默认53分钟 = 3180秒)

### 查看日志文件

日志文件保存在脚本所在目录的 `work_status_log.txt`：
```bash
# 直接查看日志文件
cat work_status_log.txt

# 或使用文本编辑器打开
open -a TextEdit work_status_log.txt
```

## 🔧 常见问题

### Q: 提醒对话框没有弹出？
A: 确保授予了Terminal辅助功能权限：
   - 打开 `系统设置` > `隐私与安全性` > `辅助功能`
   - 确保Terminal或你的终端应用在列表中且已勾选

### Q: 如何后台运行而不显示终端窗口？
A: 使用 `nohup` 命令：
```bash
nohup ./reminder_health.sh > /dev/null 2>&1 &
```
注意：这样运行时无法使用 'a' 键记录心情功能。

### Q: 如何停止提醒？
A: 
- 如果在前台运行：按 `Ctrl+C`
- 如果在后台运行：使用 `ps aux | grep reminder_health.sh` 找到进程ID，然后 `kill [PID]`

### Q: 日志文件在哪里？
A: 日志文件 `work_status_log.txt` 保存在脚本所在的目录中。

### Q: 可以更改提醒内容吗？
A: 可以！直接编辑 `reminder_health.sh` 文件中的对话框文本内容。

## 📊 日志格式说明

工作日志按以下格式记录：
```
2026-02-09 14:30:45 [逐步推进，继续执行] 完成了数据分析模块的开发
2026-02-09 14:05:20 [脱离正轨，马上调整] 被社交媒体分散注意力，需要重新聚焦
============================= 2026-02-09  =============================

2026-02-08 16:45:10 [记录心情，探索动力] 今天状态很好，解决了一个困扰很久的bug
2026-02-08 15:30:00 [逐步推进，继续执行] 正在编写测试用例
============================= 2026-02-08  =============================
```

- 每天的记录用日期分割线隔开
- 最新记录在最上方
- 每条记录包含：时间戳、状态标签、具体描述

## 🎯 使用建议

1. **保持诚实记录**：真实记录工作状态，有助于发现效率问题
2. **定期回顾**：每周回顾工作日志，总结经验教训
3. **调整间隔**：根据个人习惯调整提醒时间间隔
4. **结合番茄工作法**：可以将工作确认提醒设为25分钟配合番茄钟使用
5. **善用心情记录**：随时记录灵感、想法和心情变化

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目！

## 📄 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

本项目改编自 [Zenity-Health-Reminder-Ubuntu](https://github.com/JyiDeng/Zenity-Health-Reminder-Ubuntu)，针对macOS系统进行了优化。

## 📮 联系方式

如有问题或建议，欢迎通过GitHub Issues联系。

---

**保持健康，高效工作！💪**
