import type {NextRequest} from "next/server";
import {createSupabaseServerClient} from "@/lib/supabase/server";

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function resolveTenant(request:NextRequest){
 const supabase=await createSupabaseServerClient();
 const{data:{user},error:authError}=await supabase.auth.getUser();
 if(authError||!user)return{ok:false as const,status:401,error:"برای ادامه وارد حساب شوید."};

 const requested=request.headers.get("x-tenant-id")?.trim()||null;
 if(requested&&!UUID.test(requested))
  return{ok:false as const,status:400,error:"شناسه سازمان معتبر نیست."};

 // A global owner is resolved only by the database-backed Auth-UUID registry.
 // If the RPC is not deployed yet, ordinary tenant membership remains available;
 // owner access stays unavailable (fail closed) until the migration is applied.
 const{data:ownerFlag,error:ownerCheckError}=await supabase.rpc("is_platform_owner");
 const isPlatformOwner=!ownerCheckError&&ownerFlag===true;

 if(isPlatformOwner){
  if(!requested)
   return{ok:false as const,status:400,error:"برای دسترسی سراسری، سازمان مقصد را مشخص کنید."};

  // Platform Owner may inspect active, suspended, or archived tenants.
  // Each operational query remains scoped to this explicit tenant ID.
  const{data:tenant,error:tenantError}=await supabase.from("sports_tenants")
   .select("id").eq("id",requested).maybeSingle();
  if(tenantError)
   return{ok:false as const,status:500,error:"بررسی سازمان مقصد ناموفق بود."};
  if(!tenant)
   return{ok:false as const,status:404,error:"سازمان موردنظر یافت نشد."};

  return{
   ok:true as const,supabase,user,tenantId:tenant.id as string,
   // Compatibility adapter for existing route capability checks. This does not
   // create a tenant membership or change the principal's global identity.
   role:"owner" as const,principalType:"platform_owner" as const,isPlatformOwner:true as const
  };
 }

 let q=supabase.from("sports_tenant_memberships")
  .select("tenant_id,role,status,sports_tenants!inner(status)")
  .eq("user_id",user.id).eq("status","active")
  .eq("sports_tenants.status","active");
 if(requested)q=q.eq("tenant_id",requested);

 const{data,error}=await q;
 if(error)return{ok:false as const,status:500,error:"بررسی عضویت سازمانی ناموفق بود."};
 if(!data?.length)return{ok:false as const,status:403,error:"عضویت فعال در این سازمان ندارید."};
 if(!requested&&data.length!==1)
  return{ok:false as const,status:409,error:"برای حساب شما چند سازمان فعال وجود دارد؛ سازمان را انتخاب کنید."};

 const membership=data[0];
 return{
  ok:true as const,supabase,user,tenantId:membership.tenant_id as string,
  role:membership.role as string,principalType:"tenant_member" as const,isPlatformOwner:false as const
 };
}
