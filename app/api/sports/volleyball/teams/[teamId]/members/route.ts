import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";
import { hasTenantCapability } from "@/lib/tenancy/permissions";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const POSITIONS = ["setter","outside_hitter","opposite","middle_blocker","libero","defensive_specialist","unassigned"];

export async function GET(req: NextRequest, ctx: { params: Promise<{ teamId: string }> }) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  const { teamId } = await ctx.params;
  if (!UUID.test(teamId)) return NextResponse.json({ error: "شناسه تیم معتبر نیست." }, { status: 400 });
  const { data, error } = await c.supabase.from("sports_volleyball_team_members")
    .select("id,member_id,jersey_number,position,is_captain,status,sports_members!inner(id,full_name,sport_type,status)")
    .eq("tenant_id", c.tenantId).eq("team_id", teamId).eq("status", "active");
  if (error) return NextResponse.json({ error: "دریافت فهرست بازیکنان ناموفق بود." }, { status: 500 });
  return NextResponse.json({ players: data ?? [] }, { headers: { "Cache-Control": "private, no-store" } });
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ teamId: string }> }) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  if (!hasTenantCapability(c.role, "members:create") && !hasTenantCapability(c.role, "events:create")) return NextResponse.json({ error: "اجازه مدیریت فهرست تیم ندارید." }, { status: 403 });
  const { teamId } = await ctx.params;
  const b = await req.json().catch(() => null);
  if (!UUID.test(teamId) || !b || typeof b.member_id !== "string" || !UUID.test(b.member_id))
    return NextResponse.json({ error: "شناسه تیم یا ورزشکار معتبر نیست." }, { status: 400 });
  const jersey = b.jersey_number == null || b.jersey_number === "" ? null : Number(b.jersey_number);
  if (jersey !== null && (!Number.isInteger(jersey) || jersey < 1 || jersey > 99))
    return NextResponse.json({ error: "شماره پیراهن باید بین ۱ تا ۹۹ باشد." }, { status: 400 });
  const position = POSITIONS.includes(b.position) ? b.position : "unassigned";
  const { data, error } = await c.supabase.from("sports_volleyball_team_members").insert({
    tenant_id: c.tenantId, team_id: teamId, member_id: b.member_id,
    jersey_number: jersey, position, is_captain: b.is_captain === true,
  }).select("id,member_id,jersey_number,position,is_captain,status").single();
  if (error) return NextResponse.json({ error: "افزودن بازیکن انجام نشد؛ عضویت در سازمان و تکراری‌نبودن شماره پیراهن را بررسی کنید." }, { status: 400 });
  return NextResponse.json({ player: data }, { status: 201, headers: { "Cache-Control": "private, no-store" } });
}
