import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";
import { hasTenantCapability } from "@/lib/tenancy/permissions";

export async function GET(req: NextRequest) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  const { data, error } = await c.supabase.from("sports_volleyball_teams")
    .select("id,name,gender,age_group,category,season,home_venue,status,created_at")
    .eq("tenant_id", c.tenantId).order("created_at", { ascending: false });
  if (error) return NextResponse.json({ error: "دریافت تیم‌ها ناموفق بود." }, { status: 500 });
  return NextResponse.json({ teams: data ?? [] }, { headers: { "Cache-Control": "private, no-store" } });
}

export async function POST(req: NextRequest) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  if (!hasTenantCapability(c.role, "events:create") && !hasTenantCapability(c.role, "members:create"))
    return NextResponse.json({ error: "اجازه ساخت تیم ندارید." }, { status: 403 });
  const b = await req.json().catch(() => null);
  if (!b || typeof b.name !== "string" || b.name.trim().length < 2 || b.name.trim().length > 140)
    return NextResponse.json({ error: "نام تیم باید بین ۲ تا ۱۴۰ نویسه باشد." }, { status: 400 });
  const gender = ["women", "men", "mixed"].includes(b.gender) ? b.gender : "mixed";
  const { data, error } = await c.supabase.from("sports_volleyball_teams").insert({
    tenant_id: c.tenantId, name: b.name.trim(), gender,
    age_group: typeof b.age_group === "string" ? b.age_group.trim().slice(0,50) : null,
    category: typeof b.category === "string" ? b.category.trim().slice(0,60) : null,
    season: typeof b.season === "string" ? b.season.trim().slice(0,30) : null,
    home_venue: typeof b.home_venue === "string" ? b.home_venue.trim().slice(0,180) : null,
    created_by: c.user.id,
  }).select("id,name,gender,age_group,category,season,home_venue,status").single();
  if (error) return NextResponse.json({ error: "ثبت تیم ناموفق بود؛ احتمالاً نام یا داده تکراری است." }, { status: 400 });
  return NextResponse.json({ team: data }, { status: 201, headers: { "Cache-Control": "private, no-store" } });
}
