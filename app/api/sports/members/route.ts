import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";
import { canCreateMember } from "@/lib/tenancy/permissions";

export async function GET(req: NextRequest) {
  const context = await resolveTenant(req);
  if (!context.ok) {
    return NextResponse.json({ error: context.error }, { status: context.status });
  }

  const { data, error } = await context.supabase
    .from("sports_members")
    .select("id,full_name,sport_type,membership_number,category,status,created_at")
    .eq("tenant_id", context.tenantId)
    .order("created_at", { ascending: false });

  if (error) {
    return NextResponse.json({ error: "دریافت اعضا ناموفق بود." }, { status: 500 });
  }

  return NextResponse.json(
    { members: data ?? [] },
    { headers: { "Cache-Control": "private, no-store" } },
  );
}

export async function POST(req: NextRequest) {
  const context = await resolveTenant(req);
  if (!context.ok) {
    return NextResponse.json({ error: context.error }, { status: context.status });
  }
  if (!canCreateMember(context.role)) {
    return NextResponse.json({ error: "اجازه ثبت عضو ندارید." }, { status: 403 });
  }

  const body: unknown = await req.json().catch(() => null);
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return NextResponse.json({ error: "ساختار اطلاعات عضو معتبر نیست." }, { status: 400 });
  }

  const input = body as Record<string, unknown>;
  if ("birth_date" in input || "phone" in input) {
    return NextResponse.json(
      { error: "اطلاعات خصوصی از این مسیر عمومی پذیرفته نمی‌شود." },
      { status: 400 },
    );
  }

  const fullName = input.full_name;
  if (typeof fullName !== "string" || fullName.trim().length < 2 || fullName.trim().length > 150) {
    return NextResponse.json({ error: "نام معتبر عضو الزامی است." }, { status: 400 });
  }

  const sportType = typeof input.sport_type === "string" ? input.sport_type.trim() : null;
  if (sportType !== null && sportType.length > 100) {
    return NextResponse.json({ error: "نام رشته بیش از حد طولانی است." }, { status: 400 });
  }

  const membershipNumber = input.membership_number == null || input.membership_number === ""
    ? null
    : input.membership_number;
  if (membershipNumber !== null && (typeof membershipNumber !== "string" || membershipNumber.trim().length > 50)) {
    return NextResponse.json({ error: "شماره عضویت معتبر نیست." }, { status: 400 });
  }

  const category = input.category == null || input.category === "" ? null : input.category;
  if (category !== null && (typeof category !== "string" || category.trim().length > 100)) {
    return NextResponse.json({ error: "رده معتبر نیست." }, { status: 400 });
  }

  const { data, error } = await context.supabase
    .from("sports_members")
    .insert({
      tenant_id: context.tenantId,
      full_name: fullName.trim(),
      sport_type: sportType,
      membership_number: typeof membershipNumber === "string" ? membershipNumber.trim() : null,
      category: typeof category === "string" ? category.trim() : null,
    })
    .select("id,full_name,sport_type,membership_number,category,status")
    .single();

  if (error) {
    return NextResponse.json({ error: "ثبت عضو ناموفق بود." }, { status: 400 });
  }

  return NextResponse.json(
    { member: data },
    { status: 201, headers: { "Cache-Control": "private, no-store" } },
  );
}
