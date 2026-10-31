// Input values for the generated form.
//
// The form edits a plain tree (strings, booleans, objects, arrays). `fromTree`
// turns it into the JSON the engine reads, keeping number text exactly as typed
// so decimals are never rounded through a JavaScript double.

export class Raw {
  constructor(text) {
    this.text = text;
  }
}

const NUMBER = /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/;

export function stringifyJson(value) {
  if (value instanceof Raw) return value.text;
  if (Array.isArray(value)) return `[${value.map(stringifyJson).join(",")}]`;
  if (value && typeof value === "object") {
    const parts = Object.entries(value).map(([key, item]) => `${JSON.stringify(key)}:${stringifyJson(item)}`);
    return `{${parts.join(",")}}`;
  }
  return JSON.stringify(value);
}

export function element(shape) {
  return { ...shape, collection: false };
}

function stripZone(text) {
  return text.replace(/(Z|[+-]00:?00)$/, "");
}

/** Editable tree from example JSON. */
export function toTree(shape, json) {
  if (json === undefined || json === null) return shape.collection ? [] : emptyFor(shape);
  if (shape.collection) {
    const items = Array.isArray(json) ? json : [json];
    return items.map((item) => toTree(element(shape), item));
  }
  switch (shape.base) {
    case "context": {
      const out = {};
      for (const field of shape.fields ?? []) out[field.label] = toTree(field, json[field.label]);
      return out;
    }
    case "boolean":
      return json === true || json === "true";
    case "dateTime":
      return stripZone(String(json));
    case "any":
      return typeof json === "string" ? json : JSON.stringify(json);
    default:
      return String(json);
  }
}

export function emptyFor(shape) {
  if (shape.collection) return [];
  if (shape.base === "context") {
    const out = {};
    for (const field of shape.fields ?? []) out[field.label] = emptyFor(field);
    return out;
  }
  return shape.base === "boolean" ? false : "";
}

/** JSON value (with Raw numbers) from the tree; undefined when nothing was entered. */
export function fromTree(shape, tree) {
  if (tree === undefined || tree === null) return undefined;
  if (shape.collection) {
    const items = (Array.isArray(tree) ? tree : [tree])
      .map((item) => fromTree(element(shape), item))
      .filter((item) => item !== undefined);
    return items.length ? items : undefined;
  }
  switch (shape.base) {
    case "context": {
      const out = {};
      for (const field of shape.fields ?? []) {
        const value = fromTree(field, tree[field.label]);
        if (value !== undefined) out[field.label] = value;
      }
      return Object.keys(out).length ? out : undefined;
    }
    case "boolean":
      return Boolean(tree);
    case "number": {
      const text = String(tree).trim();
      if (text === "") return undefined;
      return NUMBER.test(text) ? new Raw(text.replace(/^\+/, "")) : text;
    }
    case "dateTime": {
      const text = String(tree).trim();
      if (text === "") return undefined;
      if (/^\d{4}-\d\d-\d\dT\d\d:\d\d$/.test(text)) return `${text}:00Z`;
      if (/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?$/.test(text)) return `${text}Z`;
      return text;
    }
    case "any": {
      const text = String(tree).trim();
      if (text === "") return undefined;
      try {
        JSON.parse(text);
        return new Raw(text);
      } catch {
        return text;
      }
    }
    default: {
      const text = String(tree);
      return text.trim() === "" ? undefined : text;
    }
  }
}

/** Request body text for the `input` field. */
export function inputText(summary, trees) {
  const body = {};
  for (const input of summary.inputs) {
    const value = fromTree(input.type, trees[input.name]);
    if (value !== undefined) body[input.name] = value;
  }
  return stringifyJson(body);
}
