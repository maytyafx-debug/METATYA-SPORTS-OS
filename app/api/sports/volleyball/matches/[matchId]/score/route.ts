import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";
import { hasTenantCapability } from "@/lib/tenancy/permissions";
import { validateVolleyballMatchScore, type VolleyballSetScore } from "@/lib/sports/volleyball/scoring";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function POST(req: NextRequest, ctx: { params: Promise<{ matchId: string }> }) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  if (!["owner","admin","referee"].includes(c.role)) return NextResponse.json({ error: "فقط داور یا مدیر مجاز به ثبت رسمی امتیاز است." }, { status: 403 });
  const { matchId } = await ctx.params;
  if (!UUID.test(matchId)) return NextResponse.json({ error: "شناسه مسابقه معتبر نیست." }, { status: 400 });
  const b = await req.json().catch(() => null);
  if (!b || !Array.isArray(b.sets) || b.sets.length > 5) return NextResponse.json({ error: "فهرست ست‌ها معتبر نیست." }, { status: 400 });
  const sets = b.sets as VolleyballSetScore[];
  const { data: match, error: matchError } = await c.supabase.from("sports_volleyball_matches")
    .select("id,best_of,status,result_status,home_team_id,away_team_id")
    .eq("id", matchId).eq("tenant_id", c.tenantId).single();
  if (matchError || !match) return NextResponse.json({ error: "مسابقه در سازمان فعال یافت نشد." }, { status: 404 });
  if (match.result_status === "approved") return NextResponse.json({ error: "نتیجه تأییدشده قفل است؛ اصلاح آن نیازمند فرایند رسمی است." }, { status: 409 });
  const validation = validateVolleyballMatchScore({ sets, bestOf: match.best_of as 3 | 5 });
  if (!validation.valid) return NextResponse.json({ error: "امتیاز مسابقه معتبر نیست.", details: validation.errors }, { status: 400 });
  const { data: oldSets } = await c.supabase.from("sports_volleyball_match_sets")
    .select("set_number,home_points,away_points").eq("tenant_id", c.tenantId).eq("match_id", matchId);
  const prior = { sets: oldSets ?? [], result_status: match.result_status };
  const { error: auditError } = await c.supabase.from("sports_volleyball_result_audit").insert({
    tenant_id: c.tenantId, match_id: matchId, actor_id: c.user.id,
    action: match.result_status === "pending" ? "score_submitted" : "score_corrected",
    prior_result: prior, new_result: { sets, ...validation },
  });
  if (auditError) return NextResponse.json({ error: "ثبت سابقه ممیزی نتیجه ناموفق بود؛ امتیاز ذخیره نشد." }, { status: 500 });
  const rows = sets.map((s, i) => ({ tenant_id: c.tenantId, match_id: matchId, set_number: i + 1,
    home_points: s.home, away_points: s.away, recorded_by: c.user.id }));
  const { error: upsertError } = await c.supabase.from("sports_volleyball_match_sets")
    .upsert(rows, { onConflict: "match_id,set_number" });
  if (upsertError) return NextResponse.json({ error: "ذخیره امتیاز ست‌ها ناموفق بود." }, { status: 500 });
  const { error: updateError } = await c.supabase.from("sports_volleyball_matches").update({
    status: "completed", result_status: "submitted", approved_by: null, approved_at: null,
  }).eq("id", matchId).eq("tenant_id", c.tenantId);
  if (updateError) return NextResponse.json({ error: "امتیاز ثبت شد اما تغییر وضعیت مسابقه ناموفق بود؛ نیازمند بررسی مدیر است." }, { status: 500 });
  return NextResponse.json({ ok: true, result: validation }, { headers: { "Cache-Control": "private, no-store" } });
}

export async function PATCH(req: NextRequest, ctx: { params: Promise<{ matchId: string }> }) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  if (!["owner","admin"].includes(c.role)) return NextResponse.json({ error: "فقط مالک یا مدیر ارشد می‌تواند نتیجه را تأیید کند." }, { status: 403 });
  const { matchId } = await ctx.params;
  const b = await req.json().catch(() => null);
  if (!UUID.test(matchId) || !b || !["approved","rejected"].includes(b.decision))
    return NextResponse.json({ error: "درخواست تأیید معتبر نیست." }, { status: 400 });
  const { data: match, error: readError } = await c.supabase.from("sports_volleyball_matches")
    .select("id,result_status").eq("id", matchId).eq("tenant_id", c.tenantId).single();
  if (readError || !match) return NextResponse.json({ error: "مسابقه یافت نشد." }, { status: 404 });
  if (match.result_status !== "submitted") return NextResponse.json({ error: "فقط نتیجه ارسال‌شده قابل بررسی است." }, { status: 409 });
  const { error: auditError } = await c.supabase.from("sports_volleyball_result_audit").insert({
    tenant_id: c.tenantId, match_id: matchId, actor_id: c.user.id,
    action: b.decision === "approved" ? "score_approved" : "score_rejected",
    new_result: { decision: b.decision }, reason: typeof b.reason === "string" ? b.reason.trim().slice(0,1000) : null,
  });
  if (auditError) return NextResponse.json({ error: "ثبت سابقه ممیزی ناموفق بود." }, { status: 500 });
  const { error } = await c.supabase.from("sports_volleyball_matches").update({
    result_status: b.decision, approved_by: b.decision === "approved" ? c.user.id : null,
    approved_at: b.decision === "approved" ? new Date().toISOString() : null,
  }).eq("id", matchId).eq("tenant_id", c.tenantId);
  if (error) return NextResponse.json({ error: "به‌روزرسانی وضعیت نتیجه ناموفق بود." }, { status: 500 });
  return NextResponse.json({ ok: true, result_status: b.decision }, { headers: { "Cache-Control": "private, no-store" } });
}
