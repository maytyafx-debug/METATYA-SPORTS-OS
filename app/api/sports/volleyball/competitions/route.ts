import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";

const FORMATS = ["league","cup","round_robin","friendly","tournament"];

export async function GET(req: NextRequest) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({error:c.error},{status:c.status});
  const {data,error}=await c.supabase.from("sports_volleyball_competitions")
    .select("id,name,format,season,start_date,end_date,status,points_win_clear,points_win_narrow,points_loss_narrow,points_loss_clear,description")
    .eq("tenant_id",c.tenantId).order("start_date",{ascending:true});
  if(error)return NextResponse.json({error:"دریافت رقابت‌ها ناموفق بود."},{status:500});
  return NextResponse.json({competitions:data??[]},{headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(req: NextRequest) {
  const c = await resolveTenant(req);
  if (!c.ok) return NextResponse.json({error:c.error},{status:c.status});
  if (!["owner","admin","staff"].includes(c.role)) return NextResponse.json({error:"اجازه ایجاد رقابت ندارید."},{status:403});
  const b=await req.json().catch(()=>null);
  if(!b||typeof b.name!=="string"||b.name.trim().length<2||b.name.trim().length>160)
    return NextResponse.json({error:"عنوان رقابت معتبر نیست."},{status:400});
  const format=FORMATS.includes(b.format)?b.format:"league";
  const {data,error}=await c.supabase.from("sports_volleyball_competitions").insert({
    tenant_id:c.tenantId,name:b.name.trim(),format,
    season:typeof b.season==="string"?b.season.trim().slice(0,30):null,
    start_date:typeof b.start_date==="string"&&b.start_date?b.start_date:null,
    end_date:typeof b.end_date==="string"&&b.end_date?b.end_date:null,
    description:typeof b.description==="string"?b.description.trim().slice(0,2000):null,
    created_by:c.user.id,
  }).select("id,name,format,season,start_date,end_date,status").single();
  if(error)return NextResponse.json({error:"ثبت رقابت ناموفق بود؛ تاریخ‌ها و اطلاعات را بررسی کنید."},{status:400});
  return NextResponse.json({competition:data},{status:201,headers:{"Cache-Control":"private, no-store"}});
}
