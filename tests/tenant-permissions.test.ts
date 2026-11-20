import assert from "node:assert/strict";
import test from "node:test";
import {
  canCreateEvent,
  canCreateMember,
  canCreateResult,
  canManageMemberships,
  canReadEvents,
  canReadMembers,
  canReadResults,
  hasTenantCapability,
} from "../lib/tenancy/permissions.ts";

test("role capabilities match the connected pilot RLS contract", () => {
  for (const role of ["owner", "admin"]) {
    assert.equal(canReadMembers(role), true);
    assert.equal(canReadEvents(role), true);
    assert.equal(canReadResults(role), true);
    assert.equal(canCreateMember(role), true);
    assert.equal(canCreateEvent(role), true);
    assert.equal(canCreateResult(role), true);
    assert.equal(hasTenantCapability(role, "members:delete"), true);
    assert.equal(hasTenantCapability(role, "events:delete"), true);
    assert.equal(hasTenantCapability(role, "results:delete"), true);
  }

  assert.equal(canReadMembers("referee"), true);
  assert.equal(canReadEvents("referee"), true);
  assert.equal(canReadResults("referee"), true);
  assert.equal(canCreateMember("referee"), false);
  assert.equal(canCreateEvent("referee"), false);
  assert.equal(canCreateResult("referee"), true);

  for (const role of ["coach", "staff", "member"]) {
    assert.equal(canReadMembers(role), false);
    assert.equal(canReadEvents(role), false);
    assert.equal(canReadResults(role), false);
    assert.equal(canCreateMember(role), false);
    assert.equal(canCreateEvent(role), false);
    assert.equal(canCreateResult(role), false);
  }
});

test("membership administration stays disabled until its RLS and API are live", () => {
  assert.equal(canManageMemberships("owner"), false);
  assert.equal(canManageMemberships("admin"), false);
  assert.equal(canManageMemberships("referee"), false);
});

test("unknown or malformed roles are denied by default", () => {
  assert.equal(hasTenantCapability("superuser", "members:delete"), false);
  assert.equal(hasTenantCapability("", "results:create"), false);
  assert.equal(hasTenantCapability("OWNER", "memberships:manage"), false);
});
