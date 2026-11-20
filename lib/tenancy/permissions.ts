export type TenantRole = "owner" | "admin" | "referee" | "coach" | "staff" | "member";

// Current pilot contract, verified against the connected Supabase RLS policies.
// Coach/staff/member capabilities remain disabled until the matching security
// migration is approved, applied, and read-back verified.
const ROLE_CAPABILITIES: Record<TenantRole, readonly string[]> = {
  owner: [
    "members:read", "members:create", "members:update", "members:delete",
    "events:read", "events:create", "events:update", "events:delete",
    "results:read", "results:create", "results:update", "results:delete",
  ],
  admin: [
    "members:read", "members:create", "members:update", "members:delete",
    "events:read", "events:create", "events:update", "events:delete",
    "results:read", "results:create", "results:update", "results:delete",
  ],
  referee: ["members:read", "events:read", "results:read", "results:create"],
  coach: [],
  staff: [],
  member: [],
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

export const canReadMembers = (role: string) => hasTenantCapability(role, "members:read");
export const canReadEvents = (role: string) => hasTenantCapability(role, "events:read");
export const canReadResults = (role: string) => hasTenantCapability(role, "results:read");
export const canCreateMember = (role: string) => hasTenantCapability(role, "members:create");
export const canCreateEvent = (role: string) => hasTenantCapability(role, "events:create");
export const canCreateResult = (role: string) => hasTenantCapability(role, "results:create");
export const canManageMemberships = (role: string) => hasTenantCapability(role, "memberships:manage");
