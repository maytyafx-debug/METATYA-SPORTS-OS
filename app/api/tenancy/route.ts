import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function GET() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data, error } = await supabase
    .from("sports_tenant_memberships")
    .select("tenant_id,role,status,sports_tenants!inner(id,name,slug,status)")
    .eq("user_id", user.id)
    .eq("status", "active")
    .eq("sports_tenants.status", "active");

  if (error) {
    return NextResponse.json(
      { error: "دریافت سازمان‌ها ناموفق بود." },
      { status: 500 },
    );
  }

  return NextResponse.json(
    { memberships: data ?? [] },
    { headers: { "Cache-Control": "private, no-store" } },
  );
}
