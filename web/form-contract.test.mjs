import assert from "node:assert/strict";
import test from "node:test";
import { inputText, toTree } from "./form.js";

function wire(type, tree) {
  return inputText({ inputs: [{ name: "x", type }] }, { x: tree });
}

test("numeric form input emits legal JSON without rounding decimal digits", () => {
  const type = {base: "number"};
  for (const [source, expected] of [
    [".5", "0.5"], ["+.5", "0.5"], ["-000.12500", "-0.12500"],
    ["1.e+12", "1e+12"], ["+000", "0"], ["-.00", "-0.00"],
    ["00010000000000000000000000001.0000000000000000001", "10000000000000000000000001.0000000000000000001"],
    ["-0.01E-2", "-0.01E-2"],
  ]) {
    const result = wire(type, source);
    assert.equal(result, '{"x":' + expected + '}');
    assert.doesNotThrow(() => JSON.parse(result));
  }
  for (const invalid of ["1e", "NaN", "1.2.3"]) {
    assert.equal(JSON.parse(wire(type, invalid)).x, invalid);
  }
  assert.equal(wire(type, " "), "{}");
});

test("loading an Any field keeps the original JSON type on the wire", () => {
  const type = {base: "any"};
  for (const seed of ["123", "true", "null", "[]", '{"a":1}', " spaced ", "", "plain", 17, false, null, ["7"], {a:2}]) {
    assert.deepEqual(JSON.parse(wire(type, toTree(type, seed))), {x:seed});
  }
  assert.equal(wire(type, toTree(type, undefined)), "{}");
  assert.deepEqual(JSON.parse(wire(type, "plain")), {x:"plain"});
  assert.deepEqual(JSON.parse(wire(type, "[true]")), {x:[true]});
});

test("temporal fields preserve the presence, absence and spelling of timezones", () => {
  for (const [base, seeds] of [
    ["dateTime", ["2024-03-31T01:30:00", "2024-03-31T01:30:00Z", "2024-03-31T01:30:00-05:00", "2024-03-31T01:30:00.000001@Europe/Paris"]],
    ["time", ["12:30:00", "12:30:00Z", "12:30:00+05:45"]],
  ]) {
    for (const seed of seeds) assert.equal(JSON.parse(wire({base}, toTree({base}, seed))).x, seed);
    assert.equal(wire({base}, ""), "{}");
    assert.equal(JSON.parse(wire({base}, "invalid")).x, "invalid");
  }
});
