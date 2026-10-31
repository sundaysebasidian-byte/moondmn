import * as dmn from "./moondmn.js";
import { examples } from "./examples.js";
import { element, emptyFor, inputText, toTree } from "./form.js";
import { layoutGraph, renderGraph } from "./graph.js";

const $ = (id) => document.getElementById(id);

function call(name, request) {
  return JSON.parse(dmn[name](JSON.stringify(request)));
}

function debounce(fn, ms) {
  let timer = 0;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

/* ---------- editor ---------- */

function createEditor(host, { onInput }) {
  const gutter = el("div", "gutter");
  const stage = el("div", "stage");
  const layer = el("div", "marks");
  const area = el("textarea");
  area.spellcheck = false;
  area.autocapitalize = "off";
  area.setAttribute("autocomplete", "off");
  area.wrap = "off";
  stage.append(layer, area);
  host.append(gutter, stage);

  let marks = new Map();

  function render() {
    const count = area.value.split("\n").length;
    const numbers = [];
    const rows = [];
    for (let i = 1; i <= count; i++) {
      const kind = marks.get(i);
      numbers.push(kind ? `<span class="${kind}">${i}</span>` : String(i));
      rows.push(kind ? `<div class="${kind}"></div>` : "<div></div>");
    }
    gutter.innerHTML = numbers.join("\n");
    layer.innerHTML = rows.join("");
    sync();
  }

  function sync() {
    gutter.scrollTop = area.scrollTop;
    layer.scrollTop = area.scrollTop;
  }

  area.addEventListener("scroll", sync);
  area.addEventListener("input", () => {
    render();
    onInput?.();
  });
  area.addEventListener("keydown", (event) => {
    if (event.key === "Tab" && !event.shiftKey) {
      event.preventDefault();
      area.setRangeText("  ", area.selectionStart, area.selectionEnd, "end");
      area.dispatchEvent(new Event("input"));
    }
  });

  render();
  return {
    host,
    get value() {
      return area.value;
    },
    set value(text) {
      area.value = text;
      area.scrollTop = 0;
      render();
    },
    mark(entries) {
      marks = new Map(entries);
      render();
    },
    reveal(line, column) {
      const lines = area.value.split("\n");
      let offset = 0;
      for (let i = 0; i < line - 1 && i < lines.length; i++) offset += lines[i].length + 1;
      offset += Math.max(0, (column || 1) - 1);
      area.focus();
      area.setSelectionRange(offset, offset);
      const top = (line - 1) * 21;
      if (top < area.scrollTop || top > area.scrollTop + area.clientHeight - 42) {
        area.scrollTop = Math.max(0, top - area.clientHeight / 3);
      }
    },
  };
}

/* ---------- state ---------- */

const state = {
  mode: "decision",
  example: null,
  summary: null,
  layout: null,
  decision: "",
  trees: {},
  seeds: {},
  shapes: {},
  result: null,
};

const editor = createEditor($("model-editor"), { onInput: () => onModelInput() });

function nowText() {
  const raw = $("now").value;
  if (!raw) return undefined;
  return `${raw.length === 16 ? `${raw}:00` : raw}Z`;
}

function setNow(iso) {
  $("now").value = iso ? iso.replace(/Z$/, "").slice(0, 19) : "";
}

/* ---------- model ---------- */

function renderIssues(entries) {
  const list = $("issues");
  list.replaceChildren();
  list.hidden = entries.length === 0;
  const marks = [];
  for (const entry of entries) {
    const item = el("li", entry.error ? "error" : "");
    const located = entry.line > 0;
    item.append(el("span", "pos", located ? `${entry.line}:${entry.column}` : ""));
    if (entry.where) item.append(el("span", "where", entry.where));
    item.append(el("span", "msg", entry.message));
    if (located) {
      marks.push([entry.line, entry.error ? "bad" : "warn"]);
      item.addEventListener("click", () => editor.reveal(entry.line, entry.column));
    }
    list.append(item);
  }
  editor.mark(marks);
}

function analyze() {
  const xml = editor.value;
  const parsed = call("parse_dmn", { xml });
  if (!parsed.ok) {
    state.summary = null;
    state.layout = null;
    renderIssues([{ error: true, line: parsed.error.line, column: parsed.error.column, message: `${parsed.error.code}: ${parsed.error.message}` }]);
    renderDecisionSelect();
    renderForm();
    run();
    return;
  }
  state.summary = parsed;
  state.layout = layoutGraph(parsed);
  const lint = call("lint", { xml });
  renderIssues(
    (lint.ok ? lint.findings : []).map((finding) => ({
      line: finding.line,
      column: finding.column,
      where: finding.decision,
      message: finding.message,
    })),
  );

  const names = parsed.decisions.map((decision) => decision.name);
  if (!names.includes(state.decision)) state.decision = finalDecision(parsed) ?? names[0] ?? "";

  for (const input of parsed.inputs) {
    const signature = JSON.stringify(input.type);
    if (state.shapes[input.name] !== signature || state.trees[input.name] === undefined) {
      const seed = state.seeds[input.name];
      state.trees[input.name] = seed === undefined ? emptyFor(input.type) : toTree(input.type, seed);
      state.shapes[input.name] = signature;
    }
  }
  renderDecisionSelect();
  renderForm();
  run();
}

/** The decision nothing else requires; the natural thing to evaluate. */
function finalDecision(summary) {
  const required = new Set(summary.edges.map((edge) => edge.from));
  const open = summary.decisions.filter((decision) => !required.has(decision.name));
  return (open.length ? open[open.length - 1] : summary.decisions[summary.decisions.length - 1])?.name;
}

const onModelInput = debounce(analyze, 250);

function renderDecisionSelect() {
  const select = $("decision");
  select.replaceChildren();
  const decisions = state.summary?.decisions ?? [];
  for (const decision of decisions) {
    const option = el("option", "", decision.name);
    option.value = decision.name;
    select.append(option);
  }
  select.value = state.decision;
  select.hidden = decisions.length === 0;
}

$("decision").addEventListener("change", (event) => selectDecision(event.target.value));

function selectDecision(name) {
  state.decision = name;
  $("decision").value = name;
  run();
}

/* ---------- form ---------- */

const rerun = debounce(() => run(), 120);

function control(shape, holder) {
  const base = shape.base;
  const allowed = shape.allowed;
  if (base === "boolean") {
    const box = el("div", "switch");
    const buttons = [true, false].map((value) => {
      const button = el("button", "", String(value));
      button.type = "button";
      button.addEventListener("click", () => {
        holder.set(value);
        sync();
        rerun();
      });
      box.append(button);
      return [value, button];
    });
    const sync = () => buttons.forEach(([value, button]) => button.setAttribute("aria-pressed", String(Boolean(holder.get()) === value)));
    sync();
    return box;
  }
  if (allowed?.kind === "enum") {
    const select = el("select");
    const current = String(holder.get() ?? "");
    if (current === "") select.append(Object.assign(el("option"), { value: "", textContent: "" }));
    for (const value of allowed.values) {
      select.append(Object.assign(el("option"), { value: String(value), textContent: String(value) }));
    }
    select.value = current;
    select.addEventListener("change", () => {
      holder.set(select.value);
      rerun();
    });
    return select;
  }
  const input = el("input");
  input.spellcheck = false;
  const types = { number: "number", date: "date", time: "time", dateTime: "datetime-local" };
  input.type = types[base] ?? "text";
  if (base === "number") {
    input.step = "any";
    if (allowed?.kind === "range") {
      input.min = allowed.min;
      input.max = allowed.max;
    }
  }
  if (base === "time" || base === "dateTime") input.step = "1";
  input.value = String(holder.get() ?? "");
  input.addEventListener("input", () => {
    holder.set(input.value);
    rerun();
  });
  return input;
}

function hint(shape) {
  return shape.allowed?.kind === "range" ? `${shape.allowed.min}–${shape.allowed.max}` : "";
}

function labelled(text, shape, child) {
  const wrap = el("label");
  const caption = el("span", "", text);
  const note = hint(shape);
  if (note) caption.append(" ", el("span", "hint", note));
  wrap.append(caption, child);
  return wrap;
}

function field(shape, label, holder) {
  if (shape.collection) return collection(shape, label, holder);
  if (shape.base === "context") {
    const group = el("div", "field");
    group.append(el("div", "label", label));
    const body = el("div", "group");
    const tree = holder.get();
    for (const inner of shape.fields ?? []) {
      body.append(
        field(inner, inner.label, {
          get: () => tree[inner.label],
          set: (value) => {
            tree[inner.label] = value;
          },
        }),
      );
    }
    group.append(body);
    return group;
  }
  const child = control(shape, holder);
  if (shape.base !== "boolean") return labelled(label, shape, child);
  const group = el("div", "field");
  group.append(el("div", "label", label), child);
  return group;
}

function collection(shape, label, holder) {
  const box = el("div", "items");
  const draw = () => {
    box.replaceChildren(el("div", "label", label));
    const items = holder.get();
    items.forEach((_, index) => {
      const row = el("div", "item");
      row.append(
        field(element(shape), "", {
          get: () => items[index],
          set: (value) => {
            items[index] = value;
          },
        }),
      );
      const remove = el("button", "icon-btn small", "×");
      remove.type = "button";
      remove.setAttribute("aria-label", "Remove");
      remove.addEventListener("click", () => {
        items.splice(index, 1);
        draw();
        rerun();
      });
      row.append(remove);
      box.append(row);
    });
    const add = el("button", "add", "+");
    add.type = "button";
    add.setAttribute("aria-label", "Add");
    add.addEventListener("click", () => {
      items.push(emptyFor(element(shape)));
      draw();
    });
    box.append(add);
  };
  draw();
  return box;
}

function renderForm() {
  const form = $("form");
  form.replaceChildren();
  for (const input of state.summary?.inputs ?? []) {
    form.append(
      field(input.type, input.name, {
        get: () => state.trees[input.name],
        set: (value) => {
          state.trees[input.name] = value;
        },
      }),
    );
  }
}

/* ---------- run ---------- */

function run() {
  const summary = state.summary;
  if (!summary || !state.decision) {
    state.result = null;
  } else {
    state.result = call("evaluate", {
      xml: editor.value,
      decision: state.decision,
      input: inputText(summary, state.trees),
      now: nowText(),
    });
  }
  renderResult();
  renderGraphView();
  renderTables();
}

function compact(value) {
  return typeof value === "string" ? value : JSON.stringify(value);
}

function valueView(res) {
  if (!["context", "list"].includes(res.type)) return el("div", "verdict", res.text);
  const rows = el("dl", "pairs");
  const entries = res.type === "context" ? Object.entries(res.value) : res.value.map((item, index) => [String(index + 1), item]);
  for (const [key, value] of entries) rows.append(el("dt", "", key), el("dd", "", compact(value)));
  return rows;
}

function renderResult() {
  const host = $("result");
  const chip = $("result-type");
  host.replaceChildren();
  chip.hidden = true;
  const result = state.result;
  if (!result) return;
  host.append(el("div", "name", state.decision));
  if (!result.ok) {
    host.append(el("div", "error", `${result.error.code}\n${result.error.message}`));
    return;
  }
  chip.hidden = false;
  chip.textContent = result.type;
  host.append(valueView(result));
}

function renderGraphView() {
  const host = $("graph");
  if (!state.layout) {
    host.replaceChildren();
    return;
  }
  const values = state.result?.ok ? state.result.values : {};
  renderGraph(host, state.layout, { selected: state.decision, values, onSelect: selectDecision });
}

/* ---------- tables ---------- */

function requiredDecisions(name) {
  const order = [];
  const visit = (current) => {
    if (order.includes(current)) return;
    const decision = state.summary.decisions.find((item) => item.name === current);
    if (!decision) return;
    order.push(current);
    for (const need of decision.requires) if (need.kind === "decision") visit(need.name);
  };
  visit(name);
  return order;
}

function entryCell(text, className) {
  const cell = el("td", className);
  if (text === "-" || text === "") {
    cell.classList.add("dash");
    cell.textContent = "–";
  } else {
    cell.textContent = text;
  }
  return cell;
}

function tableView(decision, hits, focus) {
  const table = decision.table;
  const section = el("section", `dt-section${focus ? " focus" : ""}`);
  const head = el("div", "dt-head");
  head.append(el("span", "title", decision.name), el("span", "grow"));
  const policy = table.aggregation ? `${table.hitPolicy} · ${table.aggregation}` : table.hitPolicy;
  head.append(el("span", "chip quiet", policy));
  section.append(head);

  const wrap = el("div", "dt-wrap");
  const grid = el("table", `dt${hits ? " judged" : ""}`);
  const header = el("tr");
  header.append(el("th"));
  for (const input of table.inputs) {
    const th = el("th", "", input.label || input.expression);
    th.title = input.expression;
    header.append(th);
  }
  for (const output of table.outputs) header.append(el("th", "out", output.label || output.name));
  const thead = el("thead");
  thead.append(header);
  grid.append(thead);
  const body = el("tbody");
  table.rules.forEach((rule, index) => {
    const row = el("tr", hits?.includes(index) ? "hit" : "");
    row.append(el("td", "n", String(index + 1)));
    for (const text of rule.inputs) row.append(entryCell(text));
    for (const text of rule.outputs) row.append(entryCell(text, "out"));
    row.style.cursor = "pointer";
    row.addEventListener("click", () => editor.reveal(rule.line, 1));
    body.append(row);
  });
  grid.append(body);
  wrap.append(grid);
  section.append(wrap);
  return section;
}

function renderTables() {
  const host = $("tables");
  host.replaceChildren();
  if (!state.summary || !state.decision) return;
  const hitsByName = state.result?.tables ?? {};
  for (const name of requiredDecisions(state.decision)) {
    const decision = state.summary.decisions.find((item) => item.name === name);
    if (!decision?.table) continue;
    host.append(tableView(decision, hitsByName[name]?.hits, name === state.decision));
  }
}

/* ---------- examples, files ---------- */

function loadModel(xml, { example = null } = {}) {
  state.example = example;
  state.seeds = example ? example.input : {};
  state.trees = {};
  state.shapes = {};
  if (example) {
    state.decision = example.decision;
    setNow(example.now);
  }
  editor.value = xml;
  renderExamples();
  analyze();
}

function renderExamples() {
  const nav = $("examples");
  nav.replaceChildren();
  for (const example of examples) {
    const button = el("button", "", example.title);
    button.type = "button";
    button.setAttribute("aria-pressed", String(state.example === example));
    button.addEventListener("click", () => loadModel(example.xml, { example }));
    nav.append(button);
  }
}

async function readFile(file) {
  if (!file) return;
  loadModel(await file.text());
}

$("open").addEventListener("click", () => $("file").click());
$("file").addEventListener("change", async (event) => {
  await readFile(event.target.files[0]);
  event.target.value = "";
});
editor.host.addEventListener("dragover", (event) => {
  event.preventDefault();
  editor.host.classList.add("drop");
});
editor.host.addEventListener("dragleave", () => editor.host.classList.remove("drop"));
editor.host.addEventListener("drop", async (event) => {
  event.preventDefault();
  editor.host.classList.remove("drop");
  await readFile(event.dataTransfer.files[0]);
});

$("now").addEventListener("input", () => {
  run();
  evaluateFeel();
});

/* ---------- FEEL ---------- */

function evaluateFeel() {
  const host = $("feel-result");
  host.replaceChildren();
  const expression = $("feel-expression").value;
  if (expression.trim() === "") return;
  const res = call("feel_eval", { expression, context: $("feel-context").value, now: nowText() });
  if (!res.ok) {
    host.append(el("div", "error", `${res.error.code}\n${res.error.message}`));
    return;
  }
  const row = el("div", "row");
  row.append(el("span", "chip", res.type));
  host.append(row, valueView(res));
}

const feelRun = debounce(evaluateFeel, 120);
$("feel-expression").addEventListener("input", feelRun);
$("feel-context").addEventListener("input", feelRun);
$("feel-expression").value = "sum(for n in 1..5 return n * n) / 3";
$("feel-context").value = "{}";

/* ---------- mode, theme ---------- */

function selectMode(mode) {
  state.mode = mode;
  $("view-decision").hidden = mode !== "decision";
  $("view-feel").hidden = mode !== "feel";
  $("examples").hidden = mode !== "decision";
  for (const button of $("modes").children) button.setAttribute("aria-pressed", String(button.dataset.mode === mode));
  if (mode === "feel") evaluateFeel();
}

for (const button of $("modes").children) button.addEventListener("click", () => selectMode(button.dataset.mode));

$("theme").addEventListener("click", () => {
  const root = document.documentElement;
  const dark =
    root.dataset.theme === "dark" ||
    (!root.dataset.theme && matchMedia("(prefers-color-scheme: dark)").matches);
  const next = dark ? "light" : "dark";
  root.dataset.theme = next;
  localStorage.setItem("theme", next);
});

selectMode("decision");
loadModel(examples[0].xml, { example: examples[0] });
