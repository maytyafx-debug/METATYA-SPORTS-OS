import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";
import { canCreateEvent } from "@/lib/tenancy/permissions";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function GET(req: NextRequest) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  const { data: matches, error } = await c.supabase.from("sports_volleyball_matches")
    .select("id,event_id,competition_id,stage_name,round_number,pool_code,match_number,home_team_id,away_team_id,scheduled_at,venue,best_of,status,result_status,approved_at,notes,created_at")
    .eq("tenant_id", c.tenantId).order("scheduled_at", { ascending: true });
  if (error) return NextResponse.json({ error: "دریافت مسابقات ناموفق بود." }, { status: 500 });
  const ids = (matches ?? []).map((m) => m.id);
  const { data: sets, error: setError } = ids.length
    ? await c.supabase.from("sports_volleyball_match_sets").select("match_id,set_number,home_points,away_points").eq("tenant_id", c.tenantId).in("match_id", ids).order("set_number")
    : { data: [], error: null };
  if (setError) return NextResponse.json({ error: "دریافت امتیاز ست‌ها ناموفق بود." }, { status: 500 });
  return NextResponse.json({ matches: matches ?? [], sets: sets ?? [] }, { headers: { "Cache-Control": "private, no-store" } });
}

export async function POST(req: NextRequest) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  if (!canCreateEvent(c.role)) return NextResponse.json({ error: "اجازه برنامه‌ریزی مسابقه ندارید." }, { status: 403 });
  const b = await req.json().catch(() => null);
  if (!b || typeof b.home_team_id !== "string" || !UUID.test(b.home_team_id) ||
      typeof b.away_team_id !== "string" || !UUID.test(b.away_team_id) || b.home_team_id === b.away_team_id ||
      typeof b.scheduled_at !== "string" || Number.isNaN(Date.parse(b.scheduled_at)))
    return NextResponse.json({ error: "تیم میزبان، میهمان و زمان معتبر مسابقه الزامی است." }, { status: 400 });
  const bestOf = b.best_of === 3 ? 3 : 5;
  const competitionId = typeof b.competition_id === "string" && UUID.test(b.competition_id) ? b.competition_id : null;
  if (competitionId) {
    const { data: registrations, error: registrationError } = await c.supabase
      .from("sports_volleyball_competition_teams").select("team_id")
      .eq("tenant_id", c.tenantId).eq("competition_id", competitionId)
      .eq("status", "registered").in("team_id", [b.home_team_id, b.away_team_id]);
    if (registrationError || (registrations ?? []).length !== 2)
      return NextResponse.json({ error: "هر دو تیم باید ابتدا در همین رقابت ثبت‌نام شده باشند." }, { status: 400 });
  }
  const { data, error } = await c.supabase.from("sports_volleyball_matches").insert({
    tenant_id: c.tenantId, home_team_id: b.home_team_id, away_team_id: b.away_team_id,
    competition_id: competitionId,
    stage_name: typeof b.stage_name === "string" ? b.stage_name.trim().slice(0,80) : null,
    round_number: Number.isInteger(b.round_number) && b.round_number > 0 ? b.round_number : null,
    pool_code: typeof b.pool_code === "string" ? b.pool_code.trim().slice(0,20) : null,
    match_number: typeof b.match_number === "string" ? b.match_number.trim().slice(0,40) : null,
    scheduled_at: new Date(b.scheduled_at).toISOString(), venue: typeof b.venue === "string" ? b.venue.trim().slice(0,180) : null,
    best_of: bestOf, created_by: c.user.id, notes: typeof b.notes === "string" ? b.notes.trim().slice(0,2000) : null,
  }).select("id,competition_id,stage_name,round_number,pool_code,match_number,home_team_id,away_team_id,scheduled_at,venue,best_of,status,result_status").single();
  if (error) return NextResponse.json({ error: "ثبت مسابقه ناموفق بود؛ تیم‌ها باید متعلق به همین سازمان باشند." }, { status: 400 });
  return NextResponse.json({ match: data }, { status: 201, headers: { "Cache-Control": "private, no-store" } });
}
