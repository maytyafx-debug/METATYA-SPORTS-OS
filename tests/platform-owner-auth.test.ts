import assert from "node:assert/strict";
import test from "node:test";
import {
  interpretPlatformOwnerCheck,
  parsePlatformPagination,
} from "../lib/platform/owner-auth-utils.ts";

test("only an authoritative boolean true grants Platform Owner status",()=>{
  assert.deepEqual(interpretPlatformOwnerCheck(true,null),{
    isPlatformOwner:true,unavailable:false
  });
  assert.deepEqual(interpretPlatformOwnerCheck(false,null),{
    isPlatformOwner:false,unavailable:false
  });
  assert.deepEqual(interpretPlatformOwnerCheck("true",null),{
    isPlatformOwner:false,unavailable:false
  });
  assert.deepEqual(interpretPlatformOwnerCheck(true,new Error("registry unavailable")),{
    isPlatformOwner:false,unavailable:true
  });
});

test("platform inventory pagination is bounded and deterministic",()=>{
  assert.deepEqual(parsePlatformPagination(new URLSearchParams()),{
    page:1,limit:25,from:0,to:24
  });
  assert.deepEqual(parsePlatformPagination(new URLSearchParams("page=2&limit=50")),{
    page:2,limit:50,from:50,to:99
  });
  assert.equal(parsePlatformPagination(new URLSearchParams("page=0")),null);
  assert.equal(parsePlatformPagination(new URLSearchParams("limit=101")),null);
  assert.equal(parsePlatformPagination(new URLSearchParams("page=1.5")),null);
});
