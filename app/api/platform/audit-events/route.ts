import {NextRequest,NextResponse} from "next/server";
import {requirePlatformOwner} from "@/lib/platform/owner-auth";

export async function GET(request:NextRequest){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});

 const rawLimit=request.nextUrl.searchParams.get("limit");
 const limit=rawLimit===null?50:Number(rawLimit);
 const rawBefore=request.nextUrl.searchParams.get("before");
 const before=rawBefore===null?null:Number(rawBefore);
 if(!Number.isSafeInteger(limit)||limit<1||limit>100||
    (before!==null&&(!Number.isSafeInteger(before)||before<1)))
  return NextResponse.json({error:"پارامترهای صفحه‌بندی رویدادها معتبر نیستند."},{status:400});

 const{data,error}=await owner.supabase.rpc("platform_audit_list",{
  p_limit:limit,p_before_id:before
 });
 if(error)return NextResponse.json({error:"دریافت سوابق ممیزی ناموفق بود."},{status:503});
 const events=Array.isArray(data)?data:[];
 const last=events.length?events[events.length-1]?.event_id:null;
 return NextResponse.json({events,nextCursor:last},{headers:{"Cache-Control":"private, no-store"}});
}
