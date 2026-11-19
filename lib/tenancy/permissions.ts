export type TenantRole = "owner" | "admin" | "referee" | "coach" | "staff" | "member";

const ROLE_CAPABILITIES: Record<TenantRole, readonly string[]> = {
  owner: ["members:read", "members:create", "members:update", "members:delete", "events:read", "events:create", "events:update", "events:delete", "results:read", "results:create", "results:update", "results:delete", "memberships:manage"],
  admin: ["members:read", "members:create", "members:update", "members:delete", "events:read", "events:create", "events:update", "results:read", "results:create", "results:update", "memberships:manage"],
  referee: ["members:read", "events:read", "results:read", "results:create"],
  coach: ["members:read", "events:read", "events:create", "results:read", "results:create"],
  staff: ["members:read", "members:create", "members:update", "events:read", "events:create", "results:read", "results:create"],
  member: ["events:read", "results:read"],
};

export type TenantCapability =
  | "members:read" | "members:create" | "members:update" | "members:delete"
  | "events:read" | "events:create" | "events:update" | "events:delete"
  | "results:read" | "results:create" | "results:update" | "results:delete"
  | "memberships:manage";

export function hasTenantCapability(role: string, capability: TenantCapability): boolean {
  return Object.prototype.hasOwnProperty.call(ROLE_CAPABILITIES, role)
    && ROLE_CAPABILITIES[role as TenantRole].includes(capability);
}

export const canCreateMember = (role: string) => hasTenantCapability(role, "members:create");
export const canCreateEvent = (role: string) => hasTenantCapability(role, "events:create");
export const canCreateResult = (role: string) => hasTenantCapability(role, "results:create");
export const canManageMemberships = (role: string) => hasTenantCapability(role, "memberships:manage");
