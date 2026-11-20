import {createSupabaseServerClient} from "@/lib/supabase/server";
import {interpretPlatformOwnerCheck} from "@/lib/platform/owner-auth-utils";
export {interpretPlatformOwnerCheck,parsePlatformPagination} from "@/lib/platform/owner-auth-utils";

export type PlatformAuditInput={
 action:string;
 targetType:string;
 targetId?:string|null;
 tenantId?:string|null;
 reason:string;
 metadata?:Record<string,unknown>;
};

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
