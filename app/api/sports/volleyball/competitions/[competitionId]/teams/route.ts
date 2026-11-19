import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function GET(req:NextRequest,ctx:{params:Promise<{competitionId:string}>}) {
  const c=await resolveTenant(req);
  if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
  const {competitionId}=await ctx.params;
  if(!UUID.test(competitionId))return NextResponse.json({error:"شناسه رقابت معتبر نیست."},{status:400});
  const {data,error}=await c.supabase.from("sports_volleyball_competition_teams")
    .select("id,team_id,pool_code,seed,status,registered_at").eq("tenant_id",c.tenantId).eq("competition_id",competitionId);
  if(error)return NextResponse.json({error:"دریافت تیم‌های رقابت ناموفق بود."},{status:500});
  return NextResponse.json({teams:data??[]},{headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(req:NextRequest,ctx:{params:Promise<{competitionId:string}>}) {
  const c=await resolveTenant(req);
  if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
  if(!["owner","admin","staff","coach"].includes(c.role))return NextResponse.json({error:"اجازه ثبت تیم در رقابت ندارید."},{status:403});
  const {competitionId}=await ctx.params;
  const b=await req.json().catch(()=>null);
  if(!UUID.test(competitionId)||!b||typeof b.team_id!=="string"||!UUID.test(b.team_id))
    return NextResponse.json({error:"شناسه رقابت یا تیم معتبر نیست."},{status:400});
  const seed=b.seed==null||b.seed===""?null:Number(b.seed);
  if(seed!==null&&(!Number.isInteger(seed)||seed<1||seed>999))
    return NextResponse.json({error:"سید تیم باید عدد صحیح مثبت باشد."},{status:400});
  const {data,error}=await c.supabase.from("sports_volleyball_competition_teams").insert({
    tenant_id:c.tenantId,competition_id:competitionId,team_id:b.team_id,
    pool_code:typeof b.pool_code==="string"?b.pool_code.trim().slice(0,20):null,seed,
  }).select("id,team_id,pool_code,seed,status").single();
  if(error)return NextResponse.json({error:"ثبت تیم در رقابت ناموفق بود؛ تکراری‌نبودن و تعلق تیم به سازمان را بررسی کنید."},{status:400});
  return NextResponse.json({team:data},{status:201,headers:{"Cache-Control":"private, no-store"}});
}
