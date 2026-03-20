#!/usr/bin/env python3

import json
import math
import re
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LOG_FILE = ROOT / "work_status_log.txt"
CONFIG_FILE = ROOT / "reminder_tasks.conf"
OUTPUT_FILE = ROOT / "dashboard" / "data.js"

LINE_RE = re.compile(
    r"^(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) "
    r"\[(?P<status>[^\]]+)\] "
    r"(?P<content>.+)$"
)
ASCII_WORD_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]{1,}")
CHINESE_SEGMENT_RE = re.compile(r"[\u4e00-\u9fff]{2,6}")
STOPWORDS = {
    "继续",
    "现在",
    "一下",
    "今天",
    "完成",
    "开始",
    "感觉",
    "查看",
    "处理",
    "进行",
    "东西",
    "任务",
    "状态",
    "工作",
    "提醒",
    "记录",
    "马上",
    "执行",
    "推进",
    "正轨",
    "脱离",
}
STATUS_KIND_MAP = {
    "逐步推进，继续执行": "focus",
    "脱离正轨，马上调整": "drift",
    "记录心情，探索动力": "mood",
}
KIND_LABELS = {
    "focus": "专注推进",
    "drift": "偏航调整",
    "mood": "心情记录",
    "other": "其他",
}
TASK_CATEGORY_RULES = (
    ("hydration", ("水", "喝水")),
    ("break", ("厕所", "拉伸", "活动", "站立", "休息")),
    ("focus", ("工作", "专注", "状态")),
)


def normalize_topic(token: str) -> str:
    lowered = token.lower()
    if lowered in {"pytorch", "py", "python"}:
        return "pytorch" if lowered == "pytorch" else "python"
    return token


def extract_topics(text: str) -> list[str]:
    tokens = []
    for word in ASCII_WORD_RE.findall(text):
        normalized = normalize_topic(word)
        if len(normalized) >= 2:
            tokens.append(normalized)

    for segment in CHINESE_SEGMENT_RE.findall(text):
        if segment not in STOPWORDS:
            tokens.append(segment)

    counts = Counter(tokens)
    ranked = sorted(counts.items(), key=lambda item: (-item[1], -len(item[0]), item[0]))
    return [token for token, _ in ranked[:3]]


def parse_log_entries() -> list[dict]:
    if not LOG_FILE.exists():
        return []

    entries = []
    for raw_line in LOG_FILE.read_text(encoding="utf-8").splitlines():
        match = LINE_RE.match(raw_line.strip())
        if not match:
            continue

        ts = datetime.strptime(match.group("ts"), "%Y-%m-%d %H:%M:%S")
        status = match.group("status")
        content = match.group("content")
        kind = STATUS_KIND_MAP.get(status, "other")
        topics = extract_topics(content)

        entries.append(
            {
                "timestamp": ts.isoformat(),
                "date": ts.strftime("%Y-%m-%d"),
                "hour": ts.hour,
                "weekday": ts.strftime("%a"),
                "month": ts.strftime("%Y-%m"),
                "status": status,
                "kind": kind,
                "kindLabel": KIND_LABELS.get(kind, KIND_LABELS["other"]),
                "content": content,
                "topics": topics,
            }
        )

    entries.sort(key=lambda item: item["timestamp"])
    return entries


def classify_task(title: str, prompt: str, task_type: str) -> str:
    text = f"{title} {prompt}"
    for category, keywords in TASK_CATEGORY_RULES:
        if any(keyword in text for keyword in keywords):
            return category
    if task_type == "work_check":
        return "focus"
    return "custom"


def parse_tasks() -> list[dict]:
    if not CONFIG_FILE.exists():
        return []

    tasks = []
    for raw_line in CONFIG_FILE.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        parts = line.split("|")
        while len(parts) < 6:
            parts.append("")
        name, task_type, schedule, title, prompt, choices = parts[:6]
        tasks.append(
            {
                "name": name,
                "type": task_type,
                "schedule": schedule,
                "title": title,
                "prompt": prompt.replace("\\n", "\n"),
                "choices": [choice.strip() for choice in choices.split(";") if choice.strip()],
                "category": classify_task(title, prompt, task_type),
            }
        )

    return tasks


def percent(part: int, total: int) -> float:
    if total == 0:
        return 0.0
    return round(part * 100 / total, 1)


def build_summary(entries: list[dict]) -> dict:
    total = len(entries)
    today = datetime.now().strftime("%Y-%m-%d")
    today_entries = [entry for entry in entries if entry["date"] == today]
    focus_count = sum(1 for entry in entries if entry["kind"] == "focus")
    drift_count = sum(1 for entry in entries if entry["kind"] == "drift")
    mood_count = sum(1 for entry in entries if entry["kind"] == "mood")

    return {
        "totalEntries": total,
        "focusRate": percent(focus_count, focus_count + drift_count),
        "driftRate": percent(drift_count, focus_count + drift_count),
        "moodCount": mood_count,
        "todayCount": len(today_entries),
        "currentStreak": calculate_streak(entries),
    }


def calculate_streak(entries: list[dict]) -> int:
    if not entries:
        return 0

    dates = sorted({entry["date"] for entry in entries}, reverse=True)
    streak = 0
    previous = None
    for day in dates:
        current = datetime.strptime(day, "%Y-%m-%d").date()
        if previous is None:
            previous = current
            streak = 1
            continue
        if (previous - current).days == 1:
            streak += 1
            previous = current
            continue
        break
    return streak


def build_timeline(entries: list[dict]) -> list[dict]:
    daily = defaultdict(lambda: {"focus": 0, "drift": 0, "mood": 0, "total": 0})
    for entry in entries:
        bucket = daily[entry["date"]]
        bucket["total"] += 1
        bucket[entry["kind"]] = bucket.get(entry["kind"], 0) + 1

    result = []
    for day in sorted(daily):
        focus = daily[day]["focus"]
        drift = daily[day]["drift"]
        result.append(
            {
                "date": day,
                **daily[day],
                "focusRate": percent(focus, focus + drift),
            }
        )
    return result


def build_hourly_breakdown(entries: list[dict]) -> list[dict]:
    hours = [{"hour": hour, "focus": 0, "drift": 0, "mood": 0, "total": 0} for hour in range(24)]
    for entry in entries:
        bucket = hours[entry["hour"]]
        bucket["total"] += 1
        bucket[entry["kind"]] = bucket.get(entry["kind"], 0) + 1
    return hours


def build_weekday_breakdown(entries: list[dict]) -> list[dict]:
    order = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    mapping = {day: {"weekday": day, "focus": 0, "drift": 0, "mood": 0, "total": 0} for day in order}
    for entry in entries:
        bucket = mapping.get(entry["weekday"])
        if not bucket:
            continue
        bucket["total"] += 1
        bucket[entry["kind"]] = bucket.get(entry["kind"], 0) + 1
    return [mapping[day] for day in order]


def build_topic_stats(entries: list[dict]) -> list[dict]:
    stats = defaultdict(lambda: {"focus": 0, "drift": 0, "mood": 0, "total": 0})
    for entry in entries:
        for topic in entry["topics"]:
            bucket = stats[topic]
            bucket["total"] += 1
            bucket[entry["kind"]] = bucket.get(entry["kind"], 0) + 1

    ranked = sorted(stats.items(), key=lambda item: (-item[1]["total"], item[0]))
    result = []
    for topic, values in ranked[:18]:
        focus = values["focus"]
        drift = values["drift"]
        result.append(
            {
                "topic": topic,
                **values,
                "focusRate": percent(focus, focus + drift),
            }
        )
    return result


def build_insights(entries: list[dict], hourly: list[dict], topics: list[dict]) -> list[str]:
    insights = []
    focus_hours = [bucket for bucket in hourly if bucket["focus"] > 0]
    drift_hours = [bucket for bucket in hourly if bucket["drift"] > 0]

    if focus_hours:
        best_hour = max(focus_hours, key=lambda item: (item["focus"] - item["drift"], item["focus"]))
        insights.append(f"你最容易进入推进状态的时段是 {best_hour['hour']:02d}:00，当前记录里这一小时段的专注占比最高。")

    if drift_hours:
        risk_hour = max(drift_hours, key=lambda item: (item["drift"], item["drift"] - item["focus"]))
        insights.append(f"{risk_hour['hour']:02d}:00 附近是偏航高发时段，适合提前安排短休息或切换到更小的任务。")

    if topics:
        strongest_topic = max(topics, key=lambda item: (item["focusRate"], item["focus"], item["total"]))
        if strongest_topic["focus"] > 0:
            insights.append(f"主题“{strongest_topic['topic']}”更容易带来稳定推进，当前专注率约为 {strongest_topic['focusRate']}%。")

        weakest_topic = max(topics, key=lambda item: (item["drift"], item["total"]))
        if weakest_topic["drift"] > 0:
            insights.append(f"主题“{weakest_topic['topic']}”关联的偏航记录最多，建议拆分步骤后再开始。")

    recent = entries[-10:]
    if recent:
        recent_focus = sum(1 for entry in recent if entry["kind"] == "focus")
        recent_drift = sum(1 for entry in recent if entry["kind"] == "drift")
        if recent_focus > recent_drift:
            insights.append("最近 10 条记录整体在回到正轨，当前节奏是向好的。")
        elif recent_drift > recent_focus:
            insights.append("最近 10 条记录里偏航比例偏高，建议临时缩短工作确认提醒间隔。")

    return insights[:4]


def build_data() -> dict:
    entries = parse_log_entries()
    tasks = parse_tasks()
    hourly = build_hourly_breakdown(entries)
    topics = build_topic_stats(entries)

    return {
        "generatedAt": datetime.now().isoformat(),
        "summary": build_summary(entries),
        "entries": list(reversed(entries)),
        "timeline": build_timeline(entries),
        "hourly": hourly,
        "weekday": build_weekday_breakdown(entries),
        "topics": topics,
        "tasks": tasks,
        "insights": build_insights(entries, hourly, topics),
    }


def main() -> None:
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    payload = "window.__DASHBOARD_DATA__ = " + json.dumps(build_data(), ensure_ascii=False, indent=2) + ";\n"
    OUTPUT_FILE.write_text(payload, encoding="utf-8")


if __name__ == "__main__":
    main()
