import assert from "node:assert/strict";
import test from "node:test";
import { validateVolleyballMatchScore } from "../lib/sports/volleyball/scoring.ts";

test("accepts a clean best-of-five 3-0 result", () => {
  const r = validateVolleyballMatchScore({ bestOf: 5, sets: [
    {home:25,away:18},{home:25,away:21},{home:25,away:23},
  ]});
  assert.deepEqual(r, {valid:true,homeSetsWon:3,awaySetsWon:0});
});

test("accepts a five-set match with a 15-point deciding set", () => {
  const r = validateVolleyballMatchScore({ bestOf: 5, sets: [
    {home:25,away:20},{home:22,away:25},{home:25,away:21},
    {home:23,away:25},{home:15,away:12},
  ]});
  assert.deepEqual(r, {valid:true,homeSetsWon:3,awaySetsWon:2});
});

test("accepts a best-of-three match with a 15-point deciding set", () => {
  const r = validateVolleyballMatchScore({ bestOf: 3, sets: [
    {home:25,away:19},{home:21,away:25},{home:15,away:13},
  ]});
  assert.deepEqual(r, {valid:true,homeSetsWon:2,awaySetsWon:1});
});

test("rejects tied sets, incomplete matches and insufficient two-point margins", () => {
  assert.equal(validateVolleyballMatchScore({sets:[{home:25,away:25},{home:25,away:20},{home:25,away:20}]}).valid,false);
  assert.equal(validateVolleyballMatchScore({sets:[{home:25,away:20},{home:20,away:25},{home:18,away:25}]}).valid,false);
  assert.equal(validateVolleyballMatchScore({sets:[{home:25,away:24},{home:25,away:20},{home:25,away:20}]}).valid,false);
});

test("rejects sets after a match has already been won", () => {
  const r = validateVolleyballMatchScore({sets:[
    {home:25,away:20},{home:25,away:20},{home:25,away:20},{home:0,away:0},
  ]});
  assert.equal(r.valid,false);
});

test("rejects invalid best-of format and too many sets", () => {
  assert.equal(validateVolleyballMatchScore({bestOf:4 as unknown as 3|5,sets:[]}).valid,false);
  assert.equal(validateVolleyballMatchScore({bestOf:3,sets:[
    {home:25,away:20},{home:25,away:20},{home:25,away:20},{home:0,away:0},
  ]}).valid,false);
});

test("accepts a best-of-three straight-set 2-0 result", () => {
  const r = validateVolleyballMatchScore({ bestOf: 3, sets: [
    {home:25,away:19},{home:25,away:22},
  ]});
  assert.deepEqual(r, {valid:true,homeSetsWon:2,awaySetsWon:0});
});

test("rejects malformed runtime payload entries without throwing", () => {
  const malformed: unknown[] = [null, "25-20", 42, [], {home:"25",away:20}, {home:25}];
  for (const value of malformed) {
    const result = validateVolleyballMatchScore({
      bestOf: 3,
      sets: [value, {home:25,away:20}] as never,
    });
    assert.equal(result.valid, false);
  }
});
