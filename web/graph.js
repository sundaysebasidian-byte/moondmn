// Decision requirements graph: a layered top-down layout and an SVG renderer.

const NODE_HEIGHT = 44;
const NODE_GAP = 14;
const LAYER_GAP = 36;

function nodeWidth(name) {
  return Math.min(184, Math.max(100, Math.round(name.length * 7) + 28));
}

/** Pure layout: which layer, which row, and where every node and edge goes. */
export function layoutGraph(summary) {
  const nodes = new Map();
  const add = (name, kind) => {
    if (!nodes.has(name)) nodes.set(name, { id: name, kind, w: nodeWidth(name), h: NODE_HEIGHT, layer: 0, order: nodes.size });
  };
  for (const item of summary.inputs) add(item.name, "input");
  for (const item of summary.decisions) add(item.name, "decision");
  for (const item of summary.knowledge) add(item.name, item.kind);
  const edges = summary.edges.filter((edge) => edge.from !== edge.to);
  for (const edge of edges) {
    add(edge.from, "missing");
    add(edge.to, "missing");
  }

  const incoming = new Map([...nodes.keys()].map((id) => [id, []]));
  const outgoing = new Map([...nodes.keys()].map((id) => [id, []]));
  for (const edge of edges) {
    incoming.get(edge.to).push(edge.from);
    outgoing.get(edge.from).push(edge.to);
  }

  const layerOf = new Map();
  const visiting = new Set();
  const depth = (id) => {
    if (layerOf.has(id)) return layerOf.get(id);
    if (visiting.has(id)) return 0;
    visiting.add(id);
    let layer = 0;
    for (const source of incoming.get(id)) layer = Math.max(layer, depth(source) + 1);
    visiting.delete(id);
    layerOf.set(id, layer);
    return layer;
  };
  for (const id of nodes.keys()) nodes.get(id).layer = depth(id);

  const layers = [];
  for (const node of nodes.values()) (layers[node.layer] ??= []).push(node);
  for (let i = 0; i < layers.length; i++) layers[i] ??= [];

  const position = new Map();
  const index = () => layers.forEach((layer) => layer.forEach((node, row) => position.set(node.id, row)));
  index();
  const sweep = (layer, neighbours) => {
    const key = (node) => {
      const near = neighbours.get(node.id).map((id) => position.get(id));
      return near.length ? near.reduce((a, b) => a + b, 0) / near.length : position.get(node.id);
    };
    layer.sort((a, b) => key(a) - key(b) || a.order - b.order);
    index();
  };
  for (let round = 0; round < 4; round++) {
    for (let i = 1; i < layers.length; i++) sweep(layers[i], incoming);
    for (let i = layers.length - 2; i >= 0; i--) sweep(layers[i], outgoing);
  }

  const widthOf = (layer) => layer.reduce((sum, node) => sum + node.w, 0) + Math.max(0, layer.length - 1) * NODE_GAP;
  const width = Math.max(0, ...layers.map(widthOf));
  let y = 0;
  for (const layer of layers) {
    let x = (width - widthOf(layer)) / 2;
    for (const node of layer) {
      node.x = x;
      node.y = y;
      x += node.w + NODE_GAP;
    }
    y += NODE_HEIGHT + LAYER_GAP;
  }
  const height = Math.max(0, y - LAYER_GAP);

  const placed = edges.map((edge) => {
    const from = nodes.get(edge.from);
    const to = nodes.get(edge.to);
    const x1 = from.x + from.w / 2;
    const y1 = from.y + from.h;
    const x2 = to.x + to.w / 2;
    const y2 = to.y;
    const reach = Math.max(18, (y2 - y1) / 2);
    return { ...edge, path: `M${x1},${y1} C${x1},${y1 + reach} ${x2},${y2 - reach} ${x2},${y2}` };
  });
  return { nodes: [...nodes.values()], edges: placed, width, height };
}

const SVG = "http://www.w3.org/2000/svg";

function svg(tag, attrs = {}, text) {
  const node = document.createElementNS(SVG, tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  if (text !== undefined) node.textContent = text;
  return node;
}

function brief(value, width) {
  if (value !== null && typeof value === "object") return "";
  const text = String(value);
  const room = Math.max(6, Math.floor((width - 14) / 6.6));
  return text.length > room ? `${text.slice(0, room - 1)}…` : text;
}

/** Draw `layout` into `host`. `state`: {selected, values, onSelect}. */
export function renderGraph(host, layout, state) {
  host.replaceChildren();
  if (layout.nodes.length === 0) return;
  const pad = 6;
  const root = svg("svg", {
    viewBox: `${-pad} ${-pad} ${layout.width + pad * 2} ${layout.height + pad * 2}`,
    width: layout.width + pad * 2,
    role: "img",
    "aria-label": "Decision requirements graph",
  });
  const defs = svg("defs");
  const marker = svg("marker", { id: "arrow", viewBox: "0 0 8 8", refX: "6.5", refY: "4", markerWidth: "7", markerHeight: "7", orient: "auto" });
  marker.append(svg("path", { d: "M1,1 L7,4 L1,7", class: "arrow" }));
  defs.append(marker);
  root.append(defs);

  const evaluated = new Set(Object.keys(state.values ?? {}));
  for (const edge of layout.edges) {
    const live = evaluated.has(edge.to) && (evaluated.has(edge.from) || edge.kind === "input");
    root.append(svg("path", { d: edge.path, class: `edge ${edge.kind}${live ? " live" : ""}`, "marker-end": "url(#arrow)" }));
  }
  for (const node of layout.nodes) {
    const classes = ["node", node.kind];
    if (evaluated.has(node.id)) classes.push("done");
    if (node.id === state.selected) classes.push("selected");
    const clickable = node.kind === "decision";
    if (clickable) classes.push("clickable");
    const group = svg("g", { class: classes.join(" "), transform: `translate(${node.x},${node.y})` });
    if (clickable) {
      group.setAttribute("tabindex", "0");
      group.setAttribute("role", "button");
      group.addEventListener("click", () => state.onSelect(node.id));
      group.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          state.onSelect(node.id);
        }
      });
    }
    const shown = state.values && node.id in state.values ? brief(state.values[node.id], node.w) : "";
    const hasValue = shown !== "";
    group.append(svg("rect", { width: node.w, height: node.h, rx: node.kind === "input" ? node.h / 2 : node.kind === "decision" ? 9 : 4 }));
    group.append(svg("text", { class: "name", x: node.w / 2, y: hasValue ? 19 : node.h / 2 + 4.5, "text-anchor": "middle" }, node.id));
    if (hasValue) group.append(svg("text", { class: "value", x: node.w / 2, y: 35, "text-anchor": "middle" }, shown));
    group.append(svg("title", {}, node.id));
    root.append(group);
  }
  host.append(root);
}
