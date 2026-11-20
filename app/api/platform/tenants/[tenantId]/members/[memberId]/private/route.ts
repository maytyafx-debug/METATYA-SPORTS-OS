import {NextRequest,NextResponse} from "next/server";
import {requirePlatformOwner} from "@/lib/platform/owner-auth";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validDate=(value:string)=>{
 if(!/^\d{4}-\d{2}-\d{2}$/.test(value))return false;
 const parsed=new Date(value+"T00:00:00.000Z");
 return Number.isFinite(parsed.getTime())&&parsed.toISOString().slice(0,10)===value;
};

export async function GET(
 request:NextRequest,
 context:{params:Promise<{tenantId:string;memberId:string}>}
){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});
 const{tenantId,memberId}=await context.params;
 if(!UUID.test(tenantId)||!UUID.test(memberId))
  return NextResponse.json({error:"شناسه سازمان یا عضو معتبر نیست."},{status:400});
 const reason=request.headers.get("x-audit-reason")?.trim()??"";
 if(reason.length<5||reason.length>500)
  return NextResponse.json({error:"برای مشاهده اطلاعات خصوصی، دلیل دسترسی معتبر الزامی است."},{status:400});

 const{data,error}=await owner.supabase.rpc("platform_owner_read_member_private",{
  p_member_id:memberId,p_tenant_id:tenantId,p_reason:reason
 });
 if(error)return NextResponse.json({error:"دسترسی ثبت‌شده به اطلاعات خصوصی ناموفق بود."},{status:503});
 if(!data)return NextResponse.json({error:"اطلاعات خصوصی این عضو یافت نشد."},{status:404});
 return NextResponse.json({privateData:data},{headers:{"Cache-Control":"private, no-store"}});
}

export async function PATCH(
 request:NextRequest,
 context:{params:Promise<{tenantId:string;memberId:string}>}
){
 const owner=await requirePlatformOwner();
 if(!owner.ok)return NextResponse.json({error:owner.error},{status:owner.status});
 const{tenantId,memberId}=await context.params;
 if(!UUID.test(tenantId)||!UUID.test(memberId))
  return NextResponse.json({error:"شناسه سازمان یا عضو معتبر نیست."},{status:400});
 const raw:unknown=await request.json().catch(()=>null);
 if(!raw||typeof raw!=="object"||Array.isArray(raw))
  return NextResponse.json({error:"ساختار درخواست معتبر نیست."},{status:400});
 const body=raw as Record<string,unknown>;
 const reason=typeof body.reason==="string"?body.reason.trim():"";
 if(reason.length<5||reason.length>500)
  return NextResponse.json({error:"دلیل تغییر اطلاعات خصوصی معتبر نیست."},{status:400});
 if(!("phone" in body)||!("birth_date" in body))
  return NextResponse.json({error:"برای جلوگیری از پاک‌شدن ناخواسته، هر دو فیلد خصوصی را صریحاً ارسال کنید."},{status:400});
 const phone=body.phone;
 const birthDate=body.birth_date;
 if(phone!==null&&(typeof phone!=="string"||phone.trim().length>80))
  return NextResponse.json({error:"مقدار شماره تماس معتبر نیست."},{status:400});
 if(birthDate!==null&&(typeof birthDate!=="string"||!validDate(birthDate)))
  return NextResponse.json({error:"تاریخ تولد باید به قالب YYYY-MM-DD باشد."},{status:400});

 const{data,error}=await owner.supabase.rpc("platform_owner_upsert_member_private",{
  p_member_id:memberId,p_tenant_id:tenantId,
  p_phone:typeof phone==="string"?phone.trim():null,
  p_birth_date:typeof birthDate==="string"?birthDate:null,
  p_reason:reason
 });
 if(error||data!==true)
  return NextResponse.json({error:"به‌روزرسانی اطلاعات خصوصی ثبت نشد."},{status:503});
 return NextResponse.json({ok:true},{headers:{"Cache-Control":"private, no-store"}});
}
