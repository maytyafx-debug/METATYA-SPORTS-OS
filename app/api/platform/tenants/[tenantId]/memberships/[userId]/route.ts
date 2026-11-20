import {NextRequest,NextResponse} from "next/server";
import {recordPlatformAuditEvent,requirePlatformOwner} from "@/lib/platform/owner-auth";

const ROLES=["owner","admin","referee","coach","staff","member"];
const STATUSES=["invited","active","suspended","left"];
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function PATCH(
 request:NextRequest,
 context:{params:Promise<{tenantId:string;userId:string}>}
){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});
 const{tenantId,userId}=await context.params;
 if(!UUID.test(tenantId)||!UUID.test(userId))
  return NextResponse.json({error:"شناسه سازمان یا کاربر معتبر نیست."},{status:400});
 const raw:unknown=await request.json().catch(()=>null);
 if(!raw||typeof raw!=="object"||Array.isArray(raw))
  return NextResponse.json({error:"ساختار درخواست معتبر نیست."},{status:400});
 const body=raw as Record<string,unknown>;
 const update:Record<string,string>={};
 if("role" in body){
  if(typeof body.role!=="string"||!ROLES.includes(body.role))
   return NextResponse.json({error:"نقش سازمانی معتبر نیست."},{status:400});
  update.role=body.role;
 }
 if("status" in body){
  if(typeof body.status!=="string"||!STATUSES.includes(body.status))
   return NextResponse.json({error:"وضعیت عضویت معتبر نیست."},{status:400});
  update.status=body.status;
 }
 if(!Object.keys(update).length)
  return NextResponse.json({error:"هیچ فیلد قابل‌تغییری ارسال نشده است."},{status:400});

 const audited=await recordPlatformAuditEvent(owner.supabase,{
  action:"platform.tenant_memberships.update.request",
  targetType:"sports_tenant_memberships",tenantId,
  reason:"Platform Owner requested tenant membership update",
  metadata:{user_id:userId,fields:Object.keys(update)}
 });
 if(!audited)return NextResponse.json({error:"ثبت رویداد ممیزی ناموفق بود؛ درخواست اجرا نشد."},{status:503});

 const{data,error}=await owner.supabase.from("sports_tenant_memberships").update(update)
  .eq("tenant_id",tenantId).eq("user_id",userId)
  .select("tenant_id,user_id,role,status").maybeSingle();
 if(error)return NextResponse.json({error:"به‌روزرسانی عضویت ناموفق بود؛ سازمان باید حداقل یک مالک فعال داشته باشد."},{status:400});
 if(!data)return NextResponse.json({error:"عضویت موردنظر یافت نشد."},{status:404});
 return NextResponse.json({membership:data},{headers:{"Cache-Control":"private, no-store"}});
}
