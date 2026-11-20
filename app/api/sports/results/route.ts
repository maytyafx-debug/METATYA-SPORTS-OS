import {NextRequest,NextResponse} from "next/server";
import {resolveTenant} from "@/lib/tenancy/resolve-tenant";
import { canCreateResult, canReadResults } from "@/lib/tenancy/permissions";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function GET(req:NextRequest){
 const c=await resolveTenant(req);
 if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
 if(!canReadResults(c.role))return NextResponse.json({error:"اجازه مشاهده اطلاعات عملیاتی را ندارید."},{status:403});
 const{data,error}=await c.supabase.from("sports_results")
  .select("id,member_id,event_id,score,rank,notes,created_at")
  .eq("tenant_id",c.tenantId).order("created_at",{ascending:false});
 if(error)return NextResponse.json({error:"دریافت نتایج ناموفق بود."},{status:500});
 return NextResponse.json({results:data??[]},{headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(req:NextRequest){
 const c=await resolveTenant(req);
 if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
 if(!canCreateResult(c.role))return NextResponse.json({error:"اجازه ثبت نتیجه ندارید."},{status:403});

 const b=await req.json().catch(()=>null);
 if(!b||typeof b!=="object"||Array.isArray(b)||
    typeof b.member_id!=="string"||!UUID.test(b.member_id)||
    typeof b.event_id!=="string"||!UUID.test(b.event_id))
  return NextResponse.json({error:"شناسه عضو و رویداد معتبر نیست."},{status:400});

 const score=b.score==null||b.score===""?null:Number(b.score);
 const rank=b.rank==null||b.rank===""?null:Number(b.rank);
 const notes=typeof b.notes==="string"?b.notes.trim():null;
 if(score!==null&&(!Number.isFinite(score)||Math.abs(score)>999999999))
  return NextResponse.json({error:"امتیاز یا رکورد باید عدد معتبر باشد."},{status:400});
 if(rank!==null&&(!Number.isSafeInteger(rank)||rank<1))
  return NextResponse.json({error:"رتبه باید یک عدد صحیح بزرگ‌تر از صفر باشد."},{status:400});
 if(notes!==null&&notes.length>2000)
  return NextResponse.json({error:"توضیحات نباید بیش از ۲۰۰۰ نویسه باشد."},{status:400});

 const{data,error}=await c.supabase.from("sports_results")
  .insert({tenant_id:c.tenantId,member_id:b.member_id,event_id:b.event_id,score,rank,notes})
  .select("id,member_id,event_id,score,rank,notes").single();
 if(error)return NextResponse.json({error:"ثبت نتیجه ناموفق بود؛ ارتباط عضو و رویداد با سازمان را بررسی کنید."},{status:400});
 return NextResponse.json({result:data},{status:201,headers:{"Cache-Control":"private, no-store"}});
}