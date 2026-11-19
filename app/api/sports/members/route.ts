import {NextRequest,NextResponse} from "next/server";
import {resolveTenant} from "@/lib/tenancy/resolve-tenant";
import {canCreateMember} from "@/lib/tenancy/permissions";

export async function GET(req:NextRequest){
 const c=await resolveTenant(req);
 if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
 const{data,error}=await c.supabase.from("sports_members")
  .select("id,full_name,sport_type,status,created_at")
  .eq("tenant_id",c.tenantId).order("created_at",{ascending:false});
 if(error)return NextResponse.json({error:"دریافت اعضا ناموفق بود."},{status:500});
 return NextResponse.json({members:data??[]},{headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(req:NextRequest){
 const c=await resolveTenant(req);
 if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
 if(!canCreateMember(c.role))return NextResponse.json({error:"اجازه ثبت عضو ندارید."},{status:403});
 const b=await req.json().catch(()=>null);
 if(!b||typeof b!=="object"||Array.isArray(b)||typeof b.full_name!=="string"||
    b.full_name.trim().length<2||b.full_name.trim().length>150)
  return NextResponse.json({error:"نام معتبر عضو الزامی است."},{status:400});
 const sportType=typeof b.sport_type==="string"?b.sport_type.trim():null;
 if(sportType!==null&&sportType.length>100)
  return NextResponse.json({error:"نام رشته بیش از حد طولانی است."},{status:400});
 const{data,error}=await c.supabase.from("sports_members")
  .insert({tenant_id:c.tenantId,full_name:b.full_name.trim(),sport_type:sportType})
  .select("id,full_name,sport_type,status").single();
 if(error)return NextResponse.json({error:"ثبت عضو ناموفق بود."},{status:400});
 return NextResponse.json({member:data},{status:201,headers:{"Cache-Control":"private, no-store"}});
}