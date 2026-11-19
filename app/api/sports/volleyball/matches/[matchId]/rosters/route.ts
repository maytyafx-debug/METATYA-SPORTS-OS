import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const POSITIONS=["setter","outside_hitter","opposite","middle_blocker","libero","defensive_specialist","unassigned"];

export async function GET(req:NextRequest,ctx:{params:Promise<{matchId:string}>}) {
  const c=await resolveTenant(req);
  if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
  const {matchId}=await ctx.params;
  if(!UUID.test(matchId))return NextResponse.json({error:"شناسه مسابقه معتبر نیست."},{status:400});
  const {data,error}=await c.supabase.from("sports_volleyball_match_rosters")
    .select("id,team_id,member_id,jersey_number,position,is_starter,sports_members!inner(full_name)")
    .eq("tenant_id",c.tenantId).eq("match_id",matchId);
  if(error)return NextResponse.json({error:"دریافت ترکیب مسابقه ناموفق بود."},{status:500});
  return NextResponse.json({players:data??[]},{headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(req:NextRequest,ctx:{params:Promise<{matchId:string}>}) {
  const c=await resolveTenant(req);
  if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
  if(!["owner","admin","staff","coach"].includes(c.role))return NextResponse.json({error:"اجازه ثبت ترکیب مسابقه ندارید."},{status:403});
  const {matchId}=await ctx.params;
  const b=await req.json().catch(()=>null);
  if(!UUID.test(matchId)||!b||!Array.isArray(b.players)||b.players.length<1||b.players.length>14)
    return NextResponse.json({error:"فهرست بازیکنان مسابقه باید بین ۱ تا ۱۴ نفر باشد."},{status:400});
  const rows=[];
  for(const p of b.players){
    if(!p||typeof p.team_id!=="string"||!UUID.test(p.team_id)||typeof p.member_id!=="string"||!UUID.test(p.member_id))
      return NextResponse.json({error:"شناسه تیم یا بازیکن در ترکیب معتبر نیست."},{status:400});
    const jersey=p.jersey_number==null||p.jersey_number===""?null:Number(p.jersey_number);
    if(jersey!==null&&(!Number.isInteger(jersey)||jersey<1||jersey>99))
      return NextResponse.json({error:"شماره پیراهن باید بین ۱ تا ۹۹ باشد."},{status:400});
    rows.push({tenant_id:c.tenantId,match_id:matchId,team_id:p.team_id,member_id:p.member_id,
      jersey_number:jersey,position:POSITIONS.includes(p.position)?p.position:"unassigned",is_starter:p.is_starter===true});
  }
  const {data,error}=await c.supabase.from("sports_volleyball_match_rosters")
    .upsert(rows,{onConflict:"match_id,team_id,member_id"})
    .select("id,team_id,member_id,jersey_number,position,is_starter");
  if(error)return NextResponse.json({error:"ثبت ترکیب انجام نشد؛ بازیکنان باید عضو فعال همان تیم و تیم‌ها متعلق به مسابقه باشند."},{status:400});
  return NextResponse.json({players:data??[]},{status:200,headers:{"Cache-Control":"private, no-store"}});
}
