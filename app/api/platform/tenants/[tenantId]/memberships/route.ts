import {NextRequest,NextResponse} from "next/server";
import {parsePlatformPagination,recordPlatformAuditEvent,requirePlatformOwner} from "@/lib/platform/owner-auth";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function GET(
 request:NextRequest,
 context:{params:Promise<{tenantId:string}>}
){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});

 const{tenantId}=await context.params;
 if(!UUID.test(tenantId))
  return NextResponse.json({error:"شناسه سازمان معتبر نیست."},{status:400});

 const pagination=parsePlatformPagination(request.nextUrl.searchParams);
 if(!pagination)return NextResponse.json({error:"پارامترهای صفحه‌بندی معتبر نیستند."},{status:400});

 const audited=await recordPlatformAuditEvent(owner.supabase,{
  action:"platform.tenant_memberships.list",
  targetType:"sports_tenant_memberships",
  tenantId,
  reason:"Platform Owner viewed paginated tenant membership inventory",
  metadata:{page:pagination.page,limit:pagination.limit}
 });
 if(!audited)return NextResponse.json({error:"ثبت رویداد ممیزی ناموفق بود؛ درخواست اجرا نشد."},{status:503});

 const{data,error,count}=await owner.supabase.from("sports_tenant_memberships")
  .select("tenant_id,user_id,role,status",{count:"exact"})
  .eq("tenant_id",tenantId)
  .order("role",{ascending:true})
  .range(pagination.from,pagination.to);
 if(error)return NextResponse.json({error:"دریافت عضویت‌های سازمان ناموفق بود."},{status:500});

 return NextResponse.json({
  memberships:data??[],tenantId,page:pagination.page,limit:pagination.limit,total:count??0
 },{headers:{"Cache-Control":"private, no-store"}});
}
