const data = window.__DASHBOARD_DATA__ || {
  generatedAt: null,
  summary: {},
  entries: [],
  timeline: [],
  hourly: [],
  weekday: [],
  topics: [],
  tasks: [],
  insights: [],
};

function qs(selector) {
  return document.querySelector(selector);
}

function createElement(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function renderMetrics() {
  const metrics = [
    ["总记录", data.summary.totalEntries ?? 0, "累计捕捉到的日志条数"],
    ["今日记录", data.summary.todayCount ?? 0, "今天已经形成的样本量"],
    ["专注率", `${data.summary.focusRate ?? 0}%`, "只统计推进/偏航两类"],
    ["偏航率", `${data.summary.driftRate ?? 0}%`, "越低越稳定"],
    ["连续天数", data.summary.currentStreak ?? 0, "最近连续有记录的天数"],
  ];

  const container = qs("#metricGrid");
  metrics.forEach(([label, value, meta]) => {
    const card = createElement("article", "metric-card");
    card.append(
      createElement("div", "metric-label", label),
      createElement("div", "metric-value", String(value)),
      createElement("div", "metric-meta", meta),
    );
    container.append(card);
  });
}

function renderInsights() {
  const container = qs("#insightList");
  const items = data.insights.length ? data.insights : ["当前样本还不够多，继续记录后这里会生成分析建议。"];
  items.forEach((text) => {
    container.append(createElement("div", "insight-item", text));
  });
}

function makeBarRow(label, focus, drift, mood, total, suffix) {
  const row = createElement("div", suffix === "weekday" ? "weekday-row" : "timeline-row");
  const max = Math.max(total, 1);
  const track = createElement("div", "bar-track");
  const focusSegment = createElement("div", "bar-segment focus");
  const driftSegment = createElement("div", "bar-segment drift");
  const moodSegment = createElement("div", "bar-segment mood");
  focusSegment.style.width = `${(focus / max) * 100}%`;
  driftSegment.style.width = `${(drift / max) * 100}%`;
  moodSegment.style.width = `${(mood / max) * 100}%`;
  track.append(focusSegment, driftSegment, moodSegment);
  row.append(createElement("strong", "", label), track, createElement("span", "", String(total)));
  return row;
}

function renderTimeline() {
  const container = qs("#timelineChart");
  const points = data.timeline.slice(-10);
  if (!points.length) {
    container.append(createElement("div", "muted-empty", "还没有趋势数据。"));
    return;
  }
  points.forEach((item) => {
    container.append(makeBarRow(item.date.slice(5), item.focus, item.drift, item.mood, item.total));
  });
}

function renderHeatmap() {
  const container = qs("#hourHeatmap");
  const max = Math.max(...data.hourly.map((item) => item.total), 1);
  data.hourly.forEach((item) => {
    const cell = createElement("div", "heat-cell");
    const ratio = item.total / max;
    cell.style.background = `linear-gradient(180deg, rgba(15,118,110,${0.08 + ratio * 0.42}), rgba(255,255,255,0.72))`;
    cell.append(
      createElement("strong", "", `${String(item.hour).padStart(2, "0")}:00`),
      createElement("span", "", `记录 ${item.total} 次`),
      createElement("span", "", `推进 ${item.focus} / 偏航 ${item.drift}`),
    );
    container.append(cell);
  });
}

function renderTopics() {
  const container = qs("#topicCloud");
  if (!data.topics.length) {
    container.append(createElement("div", "muted-empty", "当前样本较少，主题标签还在形成。"));
    return;
  }
  data.topics.slice(0, 12).forEach((item) => {
    const chip = createElement("div", "chip");
    chip.style.fontSize = `${14 + Math.min(item.total, 8) * 1.5}px`;
    chip.append(
      createElement("strong", "", `#${item.topic}`),
      createElement("small", "", `专注率 ${item.focusRate}%`),
    );
    container.append(chip);
  });
}

function renderWeekdays() {
  const container = qs("#weekdayChart");
  data.weekday.forEach((item) => {
    container.append(makeBarRow(item.weekday, item.focus, item.drift, item.mood, item.total, "weekday"));
  });
}

function renderTasks() {
  const container = qs("#taskList");
  const categoryLabels = {
    hydration: "补水",
    break: "活动休息",
    focus: "专注确认",
    custom: "自定义",
  };

  data.tasks.forEach((task) => {
    const card = createElement("article", "task-card");
    card.append(
      Object.assign(createElement("h3"), {
        innerHTML: `<span>${task.title}</span><span class="pill">${categoryLabels[task.category] || task.category}</span>`,
      }),
      createElement("div", "task-meta", `${task.name} · ${task.type} · ${task.schedule}`),
      createElement("div", "task-meta", task.prompt),
    );
    container.append(card);
  });
}

function pillClass(kind) {
  if (kind === "drift") return "pill drift-pill";
  if (kind === "mood") return "pill mood-pill";
  return "pill";
}

function renderEntries() {
  const statusFilter = qs("#statusFilter").value;
  const topicFilter = qs("#topicFilter").value;
  const dateFilter = qs("#dateFilter").value;
  const container = qs("#entryList");
  container.innerHTML = "";

  const filtered = data.entries.filter((entry) => {
    const statusMatch = statusFilter === "all" || entry.status === statusFilter;
    const topicMatch = topicFilter === "all" || entry.topics.includes(topicFilter);
    const dateMatch = !dateFilter || entry.date === dateFilter;
    return statusMatch && topicMatch && dateMatch;
  });

  if (!filtered.length) {
    container.append(createElement("div", "muted-empty", "当前筛选条件下没有记录。"));
    return;
  }

  filtered.slice(0, 50).forEach((entry) => {
    const card = createElement("article", "entry-card");
    const topics = entry.topics.length ? `#${entry.topics.join(" #")}` : "无主题标签";
    card.innerHTML = `
      <div class="entry-header">
        <strong>${entry.date} ${String(entry.hour).padStart(2, "0")}:00</strong>
        <span class="${pillClass(entry.kind)}">${entry.status}</span>
      </div>
      <div class="entry-meta">${topics}</div>
      <div class="entry-content">${entry.content}</div>
    `;
    container.append(card);
  });
}

function populateFilters() {
  const statusSelect = qs("#statusFilter");
  const topicSelect = qs("#topicFilter");

  [...new Set(data.entries.map((entry) => entry.status))].forEach((status) => {
    const option = createElement("option", "", status);
    option.value = status;
    statusSelect.append(option);
  });

  data.topics.slice(0, 18).forEach((item) => {
    const option = createElement("option", "", item.topic);
    option.value = item.topic;
    topicSelect.append(option);
  });

  statusSelect.addEventListener("change", renderEntries);
  topicSelect.addEventListener("change", renderEntries);
  qs("#dateFilter").addEventListener("change", renderEntries);
}

function bindRefresh() {
  const button = qs("#refreshButton");
  button.addEventListener("click", () => {
    window.location.reload();
  });
}

function renderGeneratedAt() {
  if (!data.generatedAt) return;
  const date = new Date(data.generatedAt);
  qs("#generatedAt").textContent = `数据更新时间：${date.toLocaleString("zh-CN")} · 新日志生成后重新运行 open_dashboard.sh`;
}

function init() {
  renderGeneratedAt();
  renderMetrics();
  renderInsights();
  renderTimeline();
  renderHeatmap();
  renderTopics();
  renderWeekdays();
  renderTasks();
  populateFilters();
  renderEntries();
  bindRefresh();
}

init();
