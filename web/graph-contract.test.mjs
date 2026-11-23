import assert from "node:assert/strict";
import test from "node:test";
import {layoutGraph} from "./graph.js";

test("ordering sweeps preserve geometry of disconnected and convergent decisions", () => {
  const spec = {inputs:[{name:"A"},{name:"B"}], decisions:[{name:"F"},{name:"E"},{name:"D"},{name:"Unused"}], knowledge:[],
    edges:[{from:"A",to:"D"},{from:"B",to:"E"},{from:"E",to:"F"},{from:"D",to:"F"}]};
  const g=layoutGraph(spec);
  assert.deepEqual(Object.fromEntries(g.nodes.map(n=>[n.id,n.layer])),{A:0,B:0,F:2,E:1,D:1,Unused:0});
  assert.ok(g.nodes.find(n=>n.id==="D").x>g.nodes.find(n=>n.id==="E").x);
  assert.equal(g.edges.length,4);
  assert.deepEqual(g,layoutGraph(spec));
  assert.equal(layoutGraph({inputs:[], decisions:[], knowledge:[], edges:[]}).height,0);
});
