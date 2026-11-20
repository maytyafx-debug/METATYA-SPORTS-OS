import assert from "node:assert/strict";
import test from "node:test";
import { SPORTS_OPERATIONS, sanitizeOperationsPayload } from "../lib/sports/operations.ts";

test("operational resource catalogue is explicit and tenant-owned",()=>{
  assert.equal(SPORTS_OPERATIONS.memberships.table,"sports_member_memberships");
  assert.equal(SPORTS_OPERATIONS.assessments.table,"sports_member_assessments");
  assert.equal(SPORTS_OPERATIONS.insurance.table,"sports_member_insurance");
  assert.equal(SPORTS_OPERATIONS.payments.readRoles.includes("coach"),false);
  assert.equal(SPORTS_OPERATIONS["guardian-consents"].readRoles.includes("member"),false);
});

test("payload sanitizer accepts only explicitly allowlisted fields",()=>{
  const accepted=sanitizeOperationsPayload({member_id:"member-1",membership_type:"athlete"},["member_id","membership_type"],["member_id"]);
  assert.equal(accepted.ok,true);
  const denied=sanitizeOperationsPayload({member_id:"member-1",tenant_id:"other-tenant"},["member_id"],["member_id"]);
  assert.equal(denied.ok,false);
});

test("payload sanitizer rejects missing required fields and non-object payloads",()=>{
  assert.equal(sanitizeOperationsPayload({member_id:""},["member_id"],["member_id"]).ok,false);
  assert.equal(sanitizeOperationsPayload(null,["member_id"]).ok,false);
  assert.equal(sanitizeOperationsPayload([],["member_id"]).ok,false);
});
