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
  health: {},
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
  const waterGoal = data.summary.waterGoal ?? 8;
  const metrics = [
    ["总记录", data.summary.totalEntries ?? 0, "累计捕捉到的日志条数"],
    ["今日记录", data.summary.todayCount ?? 0, "今天已经形成的样本量"],
    ["专注率", `${data.summary.focusRate ?? 0}%`, "只统计推进/偏航两类"],
    ["偏航率", `${data.summary.driftRate ?? 0}%`, "越低越稳定"],
    ["连续天数", data.summary.currentStreak ?? 0, "最近连续有记录的天数"],
    ["今日喝水", `${data.summary.todayWater ?? 0}/${waterGoal} 杯`, `还需 ${data.summary.todayWaterRemaining ?? 0} 杯`],
    ["今日如厕", `${data.summary.todayToilet ?? 0} 次`, "点击上方按钮可手动记录"],
    ["近7天喝水日均", `${data.summary.weekWaterAverage*8 ?? 0} 杯`, "按最近 7 天统计"],
    ["近7天如厕日均", `${data.summary.weekToiletAverage ?? 0} 次`, "按最近 7 天统计"],
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

function getUniqueDates() {
  const entryDates = data.entries.map((entry) => entry.date).filter(Boolean);
  const timelineDates = (data.timeline || []).map((item) => item.date).filter(Boolean);
  return [...new Set([...entryDates, ...timelineDates])].sort((a, b) => b.localeCompare(a));
}

function aggregateDateByHour(date) {
  const buckets = Array.from({ length: 24 }, (_, hour) => ({
    hour,
    focus: 0,
    drift: 0,
    total: 0,
  }));

  data.entries.forEach((entry) => {
    if (entry.date !== date) return;
    const bucket = buckets[entry.hour];
    if (!bucket) return;
    if (entry.kind === "focus") bucket.focus += 1;
    if (entry.kind === "drift") bucket.drift += 1;
    bucket.total = bucket.focus + bucket.drift;
  });

  return buckets;
}

function renderHourlyBarChart() {
  const container = qs("#hourlyBarChart");
  const dateSelect = qs("#dailyHourDateFilter");
  if (!container || !dateSelect) return;

  container.innerHTML = "";

  const selectedDate = dateSelect.value;
  if (!selectedDate) {
    container.append(createElement("div", "muted-empty", "暂无可用日期。"));
    return;
  }

  const buckets = aggregateDateByHour(selectedDate);
  const max = Math.max(...buckets.map((item) => item.total), 1);
  const selectedDateTotal = buckets.reduce((sum, item) => sum + item.total, 0);
  if (selectedDateTotal === 0) {
    container.append(createElement("div", "muted-empty", `日期 ${selectedDate} 没有可用记录。`));
    return;
  }

  const groups = [
    { label: "第 1 行：00:00 - 11:00", items: buckets.slice(0, 12) },
    { label: "第 2 行：12:00 - 23:00", items: buckets.slice(12, 24) },
  ];

  groups.forEach((group) => {
    const row = createElement("div", "hourly-row");
    const rowTitle = createElement("div", "hourly-row-title", group.label);
    const rowGrid = createElement("div", "hourly-row-grid");

    group.items.forEach((item) => {
      const bar = createElement("article", "hourly-col");
      const stack = createElement("div", "hourly-stack");
      const focus = createElement("div", "hourly-segment focus");
      const drift = createElement("div", "hourly-segment drift");
      const focusHeight = (item.focus / max) * 100;
      const driftHeight = (item.drift / max) * 100;
      focus.style.height = `${focusHeight}%`;
      drift.style.height = `${driftHeight}%`;
      stack.append(focus, drift);

      const hour = createElement("span", "hourly-hour", `${String(item.hour).padStart(2, "0")}:00`);
      const total = createElement("span", "hourly-total", `${item.total}`);
      const detail = createElement("span", "hourly-detail", `绿 ${item.focus} / 红 ${item.drift}`);
      bar.append(stack, hour, total, detail);
      rowGrid.append(bar);
    });

    row.append(rowTitle, rowGrid);
    container.append(row);
  });
}

function syncHourlyDateFilterFromEntryFilter() {
  const dateFilter = qs("#dateFilter");
  const dateSelect = qs("#dailyHourDateFilter");
  if (!dateFilter || !dateSelect || !dateFilter.value) return;
  const hasOption = [...dateSelect.options].some((option) => option.value === dateFilter.value);
  if (!hasOption) return;
  dateSelect.value = dateFilter.value;
  renderHourlyBarChart();
}

function populateHourlyDateFilter() {
  const dateSelect = qs("#dailyHourDateFilter");
  if (!dateSelect) return;

  const dates = getUniqueDates();
  dateSelect.innerHTML = "";

  if (!dates.length) {
    const empty = createElement("option", "", "暂无数据");
    empty.value = "";
    dateSelect.append(empty);
    renderHourlyBarChart();
    return;
  }

  dates.forEach((date) => {
    const option = createElement("option", "", date);
    option.value = date;
    dateSelect.append(option);
  });

  const dateFilter = qs("#dateFilter");
  const preferredDate = dateFilter?.value;
  dateSelect.value = dates.includes(preferredDate) ? preferredDate : dates[0];

  dateSelect.addEventListener("change", () => {
    if (dateFilter) {
      dateFilter.value = dateSelect.value;
      renderEntries();
    }
    renderHourlyBarChart();
  });

  renderHourlyBarChart();
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
  const dateFilter = qs("#dateFilter");

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
  dateFilter.addEventListener("change", () => {
    renderEntries();
    syncHourlyDateFilterFromEntryFilter();
  });
}

function bindRefresh() {
  const button = qs("#refreshButton");
  button.addEventListener("click", () => {
    window.location.reload();
  });
}

function bindRebuild() {
  const button = qs("#rebuildButton");
  if (!button) return;

  button.addEventListener("click", async () => {
    const originalLabel = button.textContent;
    button.disabled = true;
    button.textContent = "重建中...";

    try {
      const response = await fetch("/api/rebuild", { method: "POST" });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      window.location.reload();
    } catch (error) {
      button.disabled = false;
      button.textContent = originalLabel;
      alert("重建失败，请确认你是通过 open_dashboard.sh 打开的看板。");
    }
  });
}

function bindHealthLogger(buttonId, endpoint, pendingLabel) {
  const button = qs(buttonId);
  if (!button) return;

  button.addEventListener("click", async () => {
    const originalLabel = button.textContent;
    button.disabled = true;
    button.textContent = pendingLabel;
    try {
      const response = await fetch(endpoint, { method: "POST" });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      window.location.reload();
    } catch (error) {
      button.disabled = false;
      button.textContent = originalLabel;
      alert("记录失败，请确认看板服务已通过 open_dashboard.sh 启动。");
    }
  });
}

function renderGeneratedAt() {
  if (!data.generatedAt) return;
  const date = new Date(data.generatedAt);
  qs("#generatedAt").textContent = `数据更新时间：${date.toLocaleString("zh-CN")} · 新日志生成后重新运行 open_dashboard.sh`;
}

function safeRun(label, fn) {
  try {
    fn();
  } catch (error) {
    console.error(`[dashboard] ${label} 渲染失败`, error);
  }
}

function init() {
  safeRun("generatedAt", renderGeneratedAt);
  safeRun("metrics", renderMetrics);
  safeRun("insights", renderInsights);
  safeRun("timeline", renderTimeline);
  safeRun("heatmap", renderHeatmap);
  safeRun("topics", renderTopics);
  safeRun("weekdays", renderWeekdays);
  safeRun("tasks", renderTasks);
  safeRun("filters", populateFilters);
  safeRun("hourlyDateFilter", populateHourlyDateFilter);
  safeRun("entries", renderEntries);
  safeRun("refreshBind", bindRefresh);
  safeRun("rebuildBind", bindRebuild);
  safeRun("toiletBind", () => bindHealthLogger("#logToiletButton", "/api/log/toilet", "记录中..."));
  safeRun("waterBind", () => bindHealthLogger("#logWaterButton", "/api/log/water", "记录中..."));
}

init();
