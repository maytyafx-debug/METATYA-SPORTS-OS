import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{3}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ROLES=["first_referee","second_referee","scorer","line_judge"];

export async function GET(req:NextRequest,ctx:{params:Promise<{matchId:string}>}) {
  const c=await resolveTenant(req);
  if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
  const {matchId}=await ctx.params;
  if(!UUID.test(matchId))return NextResponse.json({error:"شناسه مسابقه معتبر نیست."},{status:400});
  const {data,error}=await c.supabase.from("sports_volleyball_match_officials")
    .select("id,user_id,official_role,status,created_at")
    .eq("tenant_id",c.tenantId).eq("match_id",matchId);
  if(error)return NextResponse.json({error:"دریافت عوامل مسابقه ناموفق بود."},{status:500});
  return NextResponse.json({officials:data??[]},{headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(req:NextRequest,ctx:{params:Promise<{matchId:string}>}) {
  const c=await resolveTenant(req);
  if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
  if(!["owner","admin"].includes(c.role))return NextResponse.json({error:"تخصیص داور و عوامل رسمی فقط با مجوز مالک یا مدیر انجام می‌شود."},{status:403});
  const {matchId}=await ctx.params;
  const b=await req.json().catch(()=>null);
  if(!UUID.test(matchId)||!b||typeof b.user_id!=="string"||!UUID.test(b.user_id)||!ROLES.includes(b.official_role))
    return NextResponse.json({error:"شناسه داور یا سمت رسمی معتبر نیست."},{status:400});
  const {data:membership,error:membershipError}=await c.supabase.from("sports_tenant_memberships")
    .select("user_id,role,status").eq("tenant_id",c.tenantId).eq("user_id",b.user_id).eq("status","active").maybeSingle();
  if(membershipError||!membership||(membership.role!=="referee"&&!(b.official_role==="scorer"&&membership.role==="staff")))
    return NextResponse.json({error:"فرد انتخاب‌شده داور یا ثبت‌کننده مجاز و فعال در همین سازمان نیست."},{status:400});
  const {data,error}=await c.supabase.from("sports_volleyball_match_officials").insert({
    tenant_id:c.tenantId,match_id:matchId,user_id:b.user_id,official_role:b.official_role,
    assigned_by:c.user.id,
  }).select("id,user_id,official_role,status").single();
  if(error)return NextResponse.json({error:"تخصیص عامل مسابقه ناموفق بود."},{status:400});
  return NextResponse.json({official:data},{status:201,headers:{"Cache-Control":"private, no-store"}});
}
