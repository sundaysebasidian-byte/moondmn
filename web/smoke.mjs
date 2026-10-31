// Smoke test for the browser bundle.
//
//   scripts/build-web.sh && node web/smoke.mjs [dist-dir]
//
// Calls the exported functions the page uses and asserts the answers for the
// built-in examples.
import assert from "node:assert/strict";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { examples } from "./examples.js";
import { fromTree, inputText, toTree } from "./form.js";
import { layoutGraph } from "./graph.js";

const here = dirname(fileURLToPath(import.meta.url));
const dist = resolve(process.argv[2] ?? resolve(here, "dist"));
const dmn = await import(pathToFileURL(resolve(dist, "moondmn.js")).href);

const call = (name, request) => JSON.parse(dmn[name](JSON.stringify(request)));
let passed = 0;
function test(name, fn) {
  try {
    fn();
    passed += 1;
    console.log(`ok   ${name}`);
  } catch (error) {
    console.error(`FAIL ${name}\n${error.stack}`);
    process.exitCode = 1;
  }
}

const expectedShape = {
  loan: { inputs: 3, decisions: 5, lint: 0 },
  insurance: { inputs: 5, decisions: 8, lint: 3 },
  subscription: { inputs: 4, decisions: 6, lint: 1 },
};

for (const example of examples) {
  const shape = expectedShape[example.id];
  const summary = call("parse_dmn", { xml: example.xml });

  test(`${example.id}: model summary`, () => {
    assert.equal(summary.ok, true);
    assert.equal(summary.inputs.length, shape.inputs);
    assert.equal(summary.decisions.length, shape.decisions);
    assert.ok(summary.decisions.some((decision) => decision.name === example.decision));
    for (const edge of summary.edges) {
      const names = new Set([...summary.inputs, ...summary.decisions, ...summary.knowledge].map((node) => node.name));
      assert.ok(names.has(edge.from) && names.has(edge.to), `${edge.from} -> ${edge.to}`);
    }
  });

  test(`${example.id}: lint`, () => {
    const lint = call("lint", { xml: example.xml });
    assert.equal(lint.ok, true);
    assert.equal(lint.findings.length, shape.lint);
    assert.ok(!lint.findings.some((finding) => finding.decision === "Base Premium"), "a fully covered enum table is not a gap");
    for (const finding of lint.findings) {
      assert.equal(finding.code, "W_POSSIBLE_GAP");
      assert.ok(finding.line > 0 && finding.column > 0);
    }
  });

  test(`${example.id}: graph layers follow requirements`, () => {
    const graph = layoutGraph(summary);
    const layer = new Map(graph.nodes.map((node) => [node.id, node.layer]));
    for (const edge of summary.edges) assert.ok(layer.get(edge.from) < layer.get(edge.to), `${edge.from} -> ${edge.to}`);
    assert.equal(graph.nodes.length, summary.inputs.length + summary.decisions.length + summary.knowledge.length);
    assert.equal(graph.edges.length, summary.edges.length);
  });

  test(`${example.id}: form round trip keeps the example input`, () => {
    const trees = Object.fromEntries(summary.inputs.map((input) => [input.name, toTree(input.type, example.input[input.name])]));
    assert.deepEqual(JSON.parse(inputText(summary, trees)), example.input);
  });

  test(`${example.id}: evaluate ${example.decision}`, () => {
    const res = call("evaluate", {
      xml: example.xml,
      decision: example.decision,
      input: inputText(
        summary,
        Object.fromEntries(summary.inputs.map((input) => [input.name, toTree(input.type, example.input[input.name])])),
      ),
      now: example.now,
    });
    assert.equal(res.ok, true, JSON.stringify(res));
    assert.deepEqual(res.value, example.expect.value);
    assert.deepEqual(Object.fromEntries(Object.entries(res.tables).map(([name, table]) => [name, table.hits])), example.expect.hits);
    assert.deepEqual(res.values[example.decision], example.expect.value);
  });
}

test("insurance: every hit policy reports its hits", () => {
  const example = examples.find((item) => item.id === "insurance");
  const res = call("evaluate", { xml: example.xml, decision: "Quote", input: example.input, now: example.now });
  const policies = Object.fromEntries(Object.entries(res.tables).map(([name, table]) => [name, table.hitPolicy]));
  assert.deepEqual(policies, {
    "Base Premium": "UNIQUE",
    Surcharges: "COLLECT",
    "Discount Rate": "COLLECT",
    "Risk Class": "PRIORITY",
    "Manual Review": "ANY",
    Notes: "RULE ORDER",
  });
});

test("loan: a failed UNIQUE table still reports the rules that matched", () => {
  const example = examples.find((item) => item.id === "loan");
  const xml = example.xml.replace('<text>&lt;= 0.35</text>', "<text>&gt; 0</text>").replace('hitPolicy="FIRST">\n      <input label="Credit Tier"><inputExpression typeRef="string"><text>Credit Tier</text></inputExpression></input>\n      <input label="Debt Ratio">', 'hitPolicy="UNIQUE">\n      <input label="Credit Tier"><inputExpression typeRef="string"><text>Credit Tier</text></inputExpression></input>\n      <input label="Debt Ratio">');
  const res = call("evaluate", { xml, decision: "Verdict", input: example.input, now: example.now });
  assert.equal(res.ok, false);
  assert.equal(res.error.code, "E_HIT_UNIQUE");
  assert.deepEqual(res.tables.Verdict.hits, [3, 4]);
});

test("loan: input values come back typed through the declared item definitions", () => {
  const example = examples.find((item) => item.id === "loan");
  const summary = call("parse_dmn", { xml: example.xml });
  const applicant = summary.inputs.find((input) => input.name === "Applicant").type;
  assert.equal(applicant.base, "context");
  const score = applicant.fields.find((field) => field.label === "Credit Score");
  assert.deepEqual(score.allowed, { kind: "range", min: 300, max: 850 });
  const employment = applicant.fields.find((field) => field.label === "Employment");
  assert.deepEqual(employment.allowed, { kind: "enum", values: ["employed", "self-employed", "retired", "unemployed"] });
  const bad = call("evaluate", { xml: example.xml, decision: "Offer", input: { ...example.input, Applicant: { ...example.input.Applicant, "Credit Score": 900 } } });
  assert.equal(bad.ok, false);
  assert.equal(bad.error.code, "E_ALLOWED_VALUES");
});

test("form: decimals stay exact and empty fields are left out", () => {
  const shape = { base: "number", collection: false };
  assert.equal(fromTree(shape, "0.1000000000000000000000000001").text, "0.1000000000000000000000000001");
  assert.equal(fromTree(shape, ""), undefined);
  const summary = { inputs: [{ name: "Amount", type: shape }, { name: "Skipped", type: shape }] };
  assert.equal(inputText(summary, { Amount: "12345678901234567890.123", Skipped: "" }), '{"Amount":12345678901234567890.123}');
});

test("feel: exact decimals, types and context", () => {
  const sum = call("feel_eval", { expression: "0.1 + 0.2" });
  assert.deepEqual([sum.ok, sum.value, sum.type], [true, 0.3, "number"]);
  const priced = call("feel_eval", { expression: "price * qty", context: '{"price": 19.99, "qty": 3}' });
  assert.equal(priced.text, "59.97");
  const text = call("feel_eval", { expression: 'upper case("moon")' });
  assert.deepEqual([text.value, text.type], ["MOON", "string"]);
  const list = call("feel_eval", { expression: "[1, 2, 3][item > 1]" });
  assert.deepEqual([list.value, list.type], [[2, 3], "list"]);
  const spaced = call("feel_eval", { expression: "Applicant Age >= 18", context: { "Applicant Age": 22 } });
  assert.equal(spaced.value, true);
});

test("feel: multi-word names work after a dot", () => {
  const res = call("feel_eval", {
    expression: "Applicant.Credit Score + Applicant.Annual Income / 1000",
    context: { Applicant: { "Credit Score": 720, "Annual Income": 72000 } },
  });
  assert.deepEqual([res.ok, res.value, res.type], [true, 792, "number"]);
  const loan = examples.find((item) => item.id === "loan");
  assert.match(loan.xml, /Applicant\.Credit Score/);
  assert.match(loan.xml, /Applicant\.Annual Income/);
});

test("feel: the clock is injected", () => {
  const res = call("feel_eval", { expression: "today()", now: "2026-03-01T09:00:00Z" });
  assert.equal(res.ok, true);
  assert.equal(res.value, "2026-03-01");
  assert.equal(res.type, "date");
  assert.equal(call("feel_eval", { expression: "today()" }).ok, false);
});

test("errors come back as JSON and never throw", () => {
  assert.equal(call("feel_eval", {expression: 'day of week(date("-2021-01-02"))'}).value, "Tuesday");
  const syntax = call("feel_eval", { expression: "1 +" });
  assert.equal(syntax.ok, false);
  assert.ok(syntax.error.code.startsWith("E_"));
  const xml = call("parse_dmn", { xml: "<definitions>" });
  assert.equal(xml.ok, false);
  assert.ok(xml.error.line >= 0);
  const namespace = call("parse_dmn", { xml: "<definitions xmlns='urn:other'/>" });
  assert.equal(namespace.error.code, "E_DMN_NAMESPACE");
  const example = examples[0];
  assert.equal(call("evaluate", { xml: example.xml, decision: "Nope" }).error.code, "E_DECISION");
  assert.equal(call("evaluate", { xml: example.xml, decision: "Offer", input: {} }).ok, false);
  assert.equal(JSON.parse(dmn.feel_eval("not json")).error.code, "E_REQUEST");
  assert.equal(JSON.parse(dmn.lint("[]")).ok, false);
  assert.equal(call("feel_eval", { expression: "1", now: "yesterday" }).ok, false);
});

test("malformed boxed conditional stays inside the JSON boundary", () => {
  const parts = ["<if><literalExpression><text>false</text></literalExpression></if>", "<then><literalExpression><text>1</text></literalExpression></then>", "<else><literalExpression><text>2</text></literalExpression></else>"];
  for (let missing = 0; missing < 3; missing++) {
    const xml = `<definitions xmlns="https://www.omg.org/spec/DMN/20230324/MODEL/"><decision id="D" name="D"><conditional>${parts.filter((_, i) => i !== missing).join("")}</conditional></decision></definitions>`;
    const response = call("evaluate", { xml, decision: "D", input: {} });
    assert.equal(response.ok, false);
    assert.equal(response.error.code, "E_DMN_SHAPE");
    assert.ok(response.error.line >= 1 && response.error.column >= 1);
  }
});

test("core typed JSON bridge serves browser evaluation too", () => {
  const xml = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><inputData id='x' name='x'><variable typeRef='date'/></inputData><decision id='d' name='d'><informationRequirement><requiredInput href='#x'/></informationRequirement><literalExpression><text>x + duration(\"P1D\")</text></literalExpression></decision></definitions>";
  assert.equal(call("evaluate", {xml, decision:"d", input:{x:"2024-02-28"}}).value, "2024-02-29");
  assert.equal(call("evaluate", {xml, decision:"d", input:{x:"2023-02-29"}}).error.code, "E_DATE_INVALID");
});

test("extreme month arithmetic retains identity and returns JSON range errors", () => {
  assert.equal(call("feel_eval", {expression:'string(date("999999999-12-31") + duration("P0M"))'}).value, "999999999-12-31");
  assert.equal(call("feel_eval", {expression:'string(date("-999999999-01-31") + duration("P0M"))'}).value, "-999999999-01-31");
  for (const expression of ['date("999999999-12-31") + duration("P1M")', 'date("-999999999-01-31") - duration("P1M")']) {
    const result = call("feel_eval", {expression});
    assert.equal(result.ok, false);
    assert.equal(result.error.code, "E_DATE_RANGE");
  }
});

console.log(`${passed} passed`);
