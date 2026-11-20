import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";
import { SPORTS_OPERATIONS, sanitizeOperationsPayload } from "@/lib/sports/operations";

type RouteContext = { params: Promise<{ resource: string }> };

export async function GET(request: NextRequest, context: RouteContext) {
  const tenant = await resolveTenant(request);
  if (!tenant.ok) return NextResponse.json({error:tenant.error},{status:tenant.status});
  const {resource}=await context.params;
  const config=SPORTS_OPERATIONS[resource];
  if (!config) return NextResponse.json({error:"منبع عملیاتی شناخته‌شده نیست."},{status:404});
  if (!config.readRoles.includes(tenant.role)) return NextResponse.json({error:"اجازه مشاهده این بخش را ندارید."},{status:403});

  const {data,error}=await tenant.supabase.from(config.table)
    .select(config.select).eq("tenant_id",tenant.tenantId)
    .order(config.orderBy ?? "created_at",{ascending:false}).limit(200);
  if(error) return NextResponse.json({error:"دریافت اطلاعات این بخش ناموفق بود."},{status:500});
  return NextResponse.json({items:data??[]},{headers:{"Cache-Control":"private, no-store"}});
}

export async function POST(request: NextRequest, context: RouteContext) {
  const tenant = await resolveTenant(request);
  if (!tenant.ok) return NextResponse.json({error:tenant.error},{status:tenant.status});
  const {resource}=await context.params;
  const config=SPORTS_OPERATIONS[resource];
  if (!config) return NextResponse.json({error:"منبع عملیاتی شناخته‌شده نیست."},{status:404});
  if (!config.writeRoles.includes(tenant.role)) return NextResponse.json({error:"اجازه ثبت در این بخش را ندارید."},{status:403});

  const body=await request.json().catch(()=>null);
  const parsed=sanitizeOperationsPayload(body,config.createFields,config.required);
  if(!parsed.ok) return NextResponse.json({error:parsed.error},{status:400});

  const record:Record<string,unknown>={...parsed.value,tenant_id:tenant.tenantId};
  if(config.actorField) record[config.actorField]=tenant.user.id;
  const {data,error}=await tenant.supabase.from(config.table)
    .insert(record).select(config.select).single();
  if(error) return NextResponse.json({error:"ثبت اطلاعات ناموفق بود؛ ارتباط‌ها، وضعیت یا داده‌های ارسالی را بررسی کنید."},{status:400});
  return NextResponse.json({item:data},{status:201,headers:{"Cache-Control":"private, no-store"}});
}

export async function PATCH(request: NextRequest, context: RouteContext) {
  const tenant = await resolveTenant(request);
  if (!tenant.ok) return NextResponse.json({error:tenant.error},{status:tenant.status});
  const {resource}=await context.params;
  const config=SPORTS_OPERATIONS[resource];
  if (!config) return NextResponse.json({error:"منبع عملیاتی شناخته‌شده نیست."},{status:404});
  if (!config.writeRoles.includes(tenant.role)) return NextResponse.json({error:"اجازه ویرایش این بخش را ندارید."},{status:403});
  if(config.updateFields.length===0) return NextResponse.json({error:"ویرایش این نوع داده از این مسیر مجاز نیست."},{status:405});

  const body=await request.json().catch(()=>null);
  if(!body||typeof body!=="object"||Array.isArray(body)||typeof (body as Record<string,unknown>).id!=="string")
    return NextResponse.json({error:"شناسه رکورد الزامی است."},{status:400});
  const source=body as Record<string,unknown>;
  const id=source.id as string;
  const patch={...source};delete patch.id;
  const parsed=sanitizeOperationsPayload(patch,config.updateFields);
  if(!parsed.ok) return NextResponse.json({error:parsed.error},{status:400});
  if(Object.keys(parsed.value).length===0) return NextResponse.json({error:"هیچ فیلدی برای ویرایش ارسال نشده است."},{status:400});
  const update:Record<string,unknown>={...parsed.value};
  if(config.updatedAt) update.updated_at=new Date().toISOString();
  if(config.actorField && ["memberships","credentials","bookings","payments","insurance"].includes(resource)) {
    update[config.actorField]=tenant.user.id;
    if(resource==="memberships" && update.status==="active") update.approved_at=new Date().toISOString();
    if(resource==="credentials" && update.verification_status==="verified") update.verified_at=new Date().toISOString();
    if(resource==="insurance" && update.insurance_status==="active") update.verified_at=new Date().toISOString();
  }
  const {data,error}=await tenant.supabase.from(config.table).update(update)
    .eq("id",id).eq("tenant_id",tenant.tenantId).select(config.select).maybeSingle();
  if(error) return NextResponse.json({error:"ویرایش اطلاعات ناموفق بود."},{status:400});
  if(!data) return NextResponse.json({error:"رکورد یافت نشد یا دسترسی ندارید."},{status:404});
  return NextResponse.json({item:data},{headers:{"Cache-Control":"private, no-store"}});
}
