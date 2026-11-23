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

test("reverse-declared requirement chains do not exhaust the host call stack", () => {
  const n=12000;
  const spec={inputs:[], decisions:Array.from({length:n},(_,i)=>({name:"d"+(n-i-1)})), knowledge:[],
    edges:Array.from({length:n-1},(_,i)=>({from:"d"+i,to:"d"+(i+1)}))};
  const graph=layoutGraph(spec);
  assert.equal(graph.nodes[0].layer,n-1);
  assert.equal(graph.nodes.at(-1).layer,0);
  assert.equal(graph.edges.length,n-1);
  // Cyclic input is rendered without infinite traversal, not claimed as executable DMN.
  const cycle=layoutGraph({...spec,decisions:[{name:"a"},{name:"b"}],edges:[{from:"a",to:"b"},{from:"b",to:"a"}]});
  assert.equal(cycle.nodes.length,2);
  assert.equal(cycle.edges.length,2);
});
