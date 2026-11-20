import {NextRequest,NextResponse} from "next/server";
import {parsePlatformPagination,recordPlatformAuditEvent,requirePlatformOwner} from "@/lib/platform/owner-auth";

export async function GET(request:NextRequest){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});

 const pagination=parsePlatformPagination(request.nextUrl.searchParams);
 if(!pagination)return NextResponse.json({error:"پارامترهای صفحه‌بندی معتبر نیستند."},{status:400});

 const audited=await recordPlatformAuditEvent(owner.supabase,{
  action:"platform.tenants.list",
  targetType:"sports_tenants",
  reason:"Platform Owner viewed paginated tenant inventory",
  metadata:{page:pagination.page,limit:pagination.limit}
 });
 if(!audited)return NextResponse.json({error:"ثبت رویداد ممیزی ناموفق بود؛ درخواست اجرا نشد."},{status:503});

 const{data,error,count}=await owner.supabase.from("sports_tenants")
  .select("id,name,slug,status",{count:"exact"})
  .order("name",{ascending:true})
  .range(pagination.from,pagination.to);
 if(error)return NextResponse.json({error:"دریافت فهرست سازمان‌ها ناموفق بود."},{status:500});

 return NextResponse.json({
  tenants:data??[],page:pagination.page,limit:pagination.limit,total:count??0
 },{headers:{"Cache-Control":"private, no-store"}});
}
