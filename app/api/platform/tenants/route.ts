import {NextRequest,NextResponse} from "next/server";
import {parsePlatformPagination,recordPlatformAuditEvent,requirePlatformOwner} from "@/lib/platform/owner-auth";

const SLUG=/^[a-z0-9]+(-[a-z0-9]+)*$/;

export async function GET(request:NextRequest){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});

 const pagination=parsePlatformPagination(request.nextUrl.searchParams);
 if(!pagination)return NextResponse.json({error:"پارامترهای صفحه‌بندی معتبر نیستند."},{status:400});

 const audited=await recordPlatformAuditEvent(owner.supabase,{
  action:"platform.tenants.list",targetType:"sports_tenants",
  reason:"Platform Owner viewed paginated tenant inventory",
  metadata:{page:pagination.page,limit:pagination.limit}
 });
 if(!audited)return NextResponse.json({error:"ثبت رویداد ممیزی ناموفق بود؛ درخواست اجرا نشد."},{status:503});

 const{data,error,count}=await owner.supabase.from("sports_tenants")
  .select("id,name,slug,status",{count:"exact"})
  .order("name",{ascending:true}).range(pagination.from,pagination.to);
 if(error)return NextResponse.json({error:"دریافت فهرست سازمان‌ها ناموفق بود."},{status:500});

 return NextResponse.json({tenants:data??[],page:pagination.page,limit:pagination.limit,total:count??0},
  {headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(request:NextRequest){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});

 const raw:unknown=await request.json().catch(()=>null);
 if(!raw||typeof raw!=="object"||Array.isArray(raw))
  return NextResponse.json({error:"ساختار درخواست معتبر نیست."},{status:400});
 const body=raw as Record<string,unknown>;
 const name=typeof body.name==="string"?body.name.trim():"";
 const slug=typeof body.slug==="string"?body.slug.trim():"";
 if(name.length<2||name.length>160||!SLUG.test(slug)||slug.length>160)
  return NextResponse.json({error:"نام یا شناسه یکتای سازمان معتبر نیست."},{status:400});

 const audited=await recordPlatformAuditEvent(owner.supabase,{
  action:"platform.tenants.create.request",targetType:"sports_tenants",
  reason:"Platform Owner requested tenant creation",metadata:{slug}
 });
 if(!audited)return NextResponse.json({error:"ثبت رویداد ممیزی ناموفق بود؛ درخواست اجرا نشد."},{status:503});

 const{data,error}=await owner.supabase.from("sports_tenants")
  .insert({name,slug,created_by:owner.user.id})
  .select("id,name,slug,status").single();
 if(error)return NextResponse.json({error:"ایجاد سازمان ناموفق بود؛ شناسه یکتا را بررسی کنید."},{status:400});

 return NextResponse.json({tenant:data},{status:201,headers:{"Cache-Control":"private, no-store"}});
}
