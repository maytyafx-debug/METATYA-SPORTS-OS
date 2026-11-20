import {NextRequest,NextResponse} from "next/server";
import {recordPlatformAuditEvent,requirePlatformOwner} from "@/lib/platform/owner-auth";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SLUG=/^[a-z0-9]+(-[a-z0-9]+)*$/;
const STATUSES=["active","suspended","archived"];

export async function PATCH(
 request:NextRequest,
 context:{params:Promise<{tenantId:string}>}
){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});

 const{tenantId}=await context.params;
 if(!UUID.test(tenantId))return NextResponse.json({error:"شناسه سازمان معتبر نیست."},{status:400});

 const raw:unknown=await request.json().catch(()=>null);
 if(!raw||typeof raw!=="object"||Array.isArray(raw))
  return NextResponse.json({error:"ساختار درخواست معتبر نیست."},{status:400});
 const body=raw as Record<string,unknown>;
 const update:Record<string,string>={};
 if("name" in body){
  if(typeof body.name!=="string"||body.name.trim().length<2||body.name.trim().length>160)
   return NextResponse.json({error:"نام سازمان معتبر نیست."},{status:400});
  update.name=body.name.trim();
 }
 if("slug" in body){
  if(typeof body.slug!=="string"||!SLUG.test(body.slug.trim())||body.slug.trim().length>160)
   return NextResponse.json({error:"شناسه یکتای سازمان معتبر نیست."},{status:400});
  update.slug=body.slug.trim();
 }
 if("status" in body){
  if(typeof body.status!=="string"||!STATUSES.includes(body.status))
   return NextResponse.json({error:"وضعیت سازمان معتبر نیست."},{status:400});
  update.status=body.status;
 }
 if(!Object.keys(update).length)
  return NextResponse.json({error:"هیچ فیلد قابل‌تغییری ارسال نشده است."},{status:400});

 const audited=await recordPlatformAuditEvent(owner.supabase,{
  action:"platform.tenants.update.request",targetType:"sports_tenants",targetId:tenantId,
  reason:"Platform Owner requested tenant configuration update",
  metadata:{fields:Object.keys(update)}
 });
 if(!audited)return NextResponse.json({error:"ثبت رویداد ممیزی ناموفق بود؛ درخواست اجرا نشد."},{status:503});

 const{data,error}=await owner.supabase.from("sports_tenants").update(update)
  .eq("id",tenantId).select("id,name,slug,status").maybeSingle();
 if(error)return NextResponse.json({error:"به‌روزرسانی سازمان ناموفق بود."},{status:400});
 if(!data)return NextResponse.json({error:"سازمان یافت نشد."},{status:404});
 return NextResponse.json({tenant:data},{headers:{"Cache-Control":"private, no-store"}});
}
