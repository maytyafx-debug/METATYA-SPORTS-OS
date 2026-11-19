import assert from "node:assert/strict";
import test from "node:test";
import {
  canCreateEvent,
  canCreateMember,
  canCreateResult,
  canManageMemberships,
  hasTenantCapability,
} from "../lib/tenancy/permissions.ts";

test("canonical role capabilities", () => {
  assert.equal(canCreateMember("owner"), true);
  assert.equal(canCreateMember("admin"), true);
  assert.equal(canCreateMember("staff"), true);
  assert.equal(canCreateMember("coach"), false);
  assert.equal(canCreateMember("referee"), false);
  assert.equal(canCreateMember("member"), false);

  assert.equal(canCreateEvent("coach"), true);
  assert.equal(canCreateEvent("referee"), false);
  assert.equal(canCreateResult("referee"), true);
  assert.equal(canCreateResult("coach"), true);
  assert.equal(canCreateResult("member"), false);

  assert.equal(canManageMemberships("owner"), true);
  assert.equal(canManageMemberships("admin"), true);
  assert.equal(canManageMemberships("referee"), false);
});

test("unknown or malformed roles are denied by default", () => {
  assert.equal(hasTenantCapability("superuser", "members:delete"), false);
  assert.equal(hasTenantCapability("", "results:create"), false);
  assert.equal(hasTenantCapability("OWNER", "memberships:manage"), false);
});
