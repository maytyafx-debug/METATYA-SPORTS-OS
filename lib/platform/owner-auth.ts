import {createSupabaseServerClient} from "@/lib/supabase/server";

export type PlatformAuditInput={
 action:string;
 targetType:string;
 targetId?:string|null;
 tenantId?:string|null;
 reason:string;
 metadata?:Record<string,unknown>;
};

export function interpretPlatformOwnerCheck(data:unknown,error:unknown){
 if(error)return{isPlatformOwner:false,unavailable:true} as const;
 return{isPlatformOwner:data===true,unavailable:false} as const;
}

export function parsePlatformPagination(params:URLSearchParams){
 const rawPage=params.get("page");
 const rawLimit=params.get("limit");
 const page=rawPage===null?1:Number(rawPage);
 const limit=rawLimit===null?25:Number(rawLimit);
 if(!Number.isSafeInteger(page)||page<1||page>100000||
    !Number.isSafeInteger(limit)||limit<1||limit>100)
  return null;
 return{page,limit,from:(page-1)*limit,to:(page*limit)-1};
}

export async function requirePlatformOwner(){
 const supabase=await createSupabaseServerClient();
 const{data:{user},error:authError}=await supabase.auth.getUser();
 if(authError||!user)
  return{ok:false as const,status:401,error:"برای ادامه وارد حساب شوید."};

 const{data,error}=await supabase.rpc("is_platform_owner");
 const check=interpretPlatformOwnerCheck(data,error);
 if(check.unavailable)
  return{ok:false as const,status:503,error:"سرویس احراز مالکیت سراسری هنوز آماده نیست."};
 if(!check.isPlatformOwner)
  return{ok:false as const,status:403,error:"این عملیات فقط برای مالک اصلی پلتفرم مجاز است."};

 return{ok:true as const,supabase,user};
}

export async function recordPlatformAuditEvent(
 supabase:Awaited<ReturnType<typeof createSupabaseServerClient>>,
 event:PlatformAuditInput
){
 const{error}=await supabase.rpc("platform_audit_record",{
  p_action:event.action,
  p_target_type:event.targetType,
  p_target_id:event.targetId??null,
  p_tenant_id:event.tenantId??null,
  p_reason:event.reason,
  p_metadata:event.metadata??{}
 });
 return!error;
}
