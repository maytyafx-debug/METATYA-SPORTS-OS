import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";
import { validateVolleyballMatchScore, type VolleyballSetScore } from "@/lib/sports/volleyball/scoring";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function POST(req: NextRequest, ctx: { params: Promise<{ matchId: string }> }) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  if (!["owner","admin","referee"].includes(c.role))
    return NextResponse.json({ error: "فقط داور یا مدیر مجاز به ثبت رسمی امتیاز است." }, { status: 403 });
  const { matchId } = await ctx.params;
  if (!UUID.test(matchId)) return NextResponse.json({ error: "شناسه مسابقه معتبر نیست." }, { status: 400 });
  const rawBody: unknown = await req.json().catch(() => null);
  if (!rawBody || typeof rawBody !== "object" || Array.isArray(rawBody))
    return NextResponse.json({ error: "ساختار درخواست معتبر نیست." }, { status: 400 });
  const body = rawBody as Record<string, unknown>;
  if (!Array.isArray(body.sets) || body.sets.length > 5)
    return NextResponse.json({ error: "فهرست ست‌ها معتبر نیست." }, { status: 400 });
  const sets: VolleyballSetScore[] = [];
  for (const [index, candidate] of body.sets.entries()) {
    if (!candidate || typeof candidate !== "object" || Array.isArray(candidate))
      return NextResponse.json({ error: `ساختار امتیاز ست ${index + 1} معتبر نیست.` }, { status: 400 });
    const score = candidate as Record<string, unknown>;
    if (!Number.isSafeInteger(score.home) || !Number.isSafeInteger(score.away) ||
        (score.home as number) < 0 || (score.away as number) < 0 ||
        (score.home as number) > 99 || (score.away as number) > 99)
      return NextResponse.json({ error: `امتیاز ست ${index + 1} باید دو عدد صحیح بین ۰ تا ۹۹ باشد.` }, { status: 400 });
    sets.push({ home: score.home as number, away: score.away as number });
  }
  const { data: match, error: matchError } = await c.supabase.from("sports_volleyball_matches")
    .select("id,best_of,result_status").eq("id", matchId).eq("tenant_id", c.tenantId).single();
  if (matchError || !match) return NextResponse.json({ error: "مسابقه در سازمان فعال یافت نشد." }, { status: 404 });
  if (match.result_status === "approved")
    return NextResponse.json({ error: "نتیجه تأییدشده قفل است؛ اصلاح آن نیازمند فرایند رسمی است." }, { status: 409 });
  const validation = validateVolleyballMatchScore({ sets, bestOf: match.best_of as 3 | 5 });
  if (!validation.valid) return NextResponse.json({ error: "امتیاز مسابقه معتبر نیست.", details: validation.errors }, { status: 400 });
  const { data, error } = await c.supabase.rpc("sports_volleyball_submit_score", {
    p_tenant_id: c.tenantId, p_match_id: matchId, p_sets: sets,
  });
  if (error) return NextResponse.json({ error: "ثبت تراکنشی نتیجه ناموفق بود؛ وضعیت مسابقه تغییر نکرده است." }, { status: 400 });
  return NextResponse.json(data, { headers: { "Cache-Control": "private, no-store" } });
}

export async function PATCH(req: NextRequest, ctx: { params: Promise<{ matchId: string }> }) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({ error: c.error }, { status: c.status });
  if (!["owner","admin"].includes(c.role))
    return NextResponse.json({ error: "فقط مالک یا مدیر ارشد می‌تواند نتیجه را تأیید کند." }, { status: 403 });
  const { matchId } = await ctx.params;
  const rawBody: unknown = await req.json().catch(() => null);
  if (!rawBody || typeof rawBody !== "object" || Array.isArray(rawBody))
    return NextResponse.json({ error: "درخواست تأیید معتبر نیست." }, { status: 400 });
  const body = rawBody as Record<string, unknown>;
  if (!UUID.test(matchId) || (body.decision !== "approved" && body.decision !== "rejected"))
    return NextResponse.json({ error: "درخواست تأیید معتبر نیست." }, { status: 400 });
  const { data, error } = await c.supabase.rpc("sports_volleyball_decide_result", {
    p_tenant_id: c.tenantId, p_match_id: matchId, p_decision: body.decision,
    p_reason: typeof body.reason === "string" ? body.reason.trim().slice(0,1000) : null,
  });
  if (error) return NextResponse.json({ error: "تغییر وضعیت نتیجه ناموفق بود؛ سابقه ممیزی و نتیجه دست‌نخورده باقی ماند." }, { status: 400 });
  return NextResponse.json(data, { headers: { "Cache-Control": "private, no-store" } });
}
