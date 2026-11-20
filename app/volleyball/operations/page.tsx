"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";

type FieldKind = "text" | "long" | "number" | "date" | "datetime" | "json" | "select";
type FieldSpec = { key:string; label:string; kind?:FieldKind; options?:string[]; required?:boolean; hint?:string };
type ResourceSpec = { key:string; title:string; group:string; description:string; fields:FieldSpec[] };
type RecordRow = Record<string,unknown> & {id?:string};

const RESOURCES:ResourceSpec[] = [
 {key:"org-units",title:"ساختار سازمانی",group:"مدیریت هیئت",description:"فدراسیون، هیئت استان، شهرستان، باشگاه، آکادمی و شعبه",fields:[
  {key:"unit_type",label:"نوع واحد",kind:"select",options:["federation","province_board","county_board","association","club","academy","branch","department"],required:true},
  {key:"name",label:"نام واحد",required:true},{key:"code",label:"کد سازمانی"},
  {key:"parent_id",label:"شناسه واحد بالادستی",hint:"در صورت وجود، UUID واحد بالادستی را وارد کنید."}
 ]},
 {key:"memberships",title:"عضویت ورزشکاران",group:"مدیریت هیئت",description:"ثبت، تمدید، تعلیق، لغو و پیگیری وضعیت عضویت",fields:[
  {key:"member_id",label:"شناسه عضو",required:true},{key:"membership_number",label:"شماره عضویت"},
  {key:"membership_type",label:"نوع عضویت",kind:"select",options:["athlete","coach","referee","staff","honorary","other"],required:true},
  {key:"valid_from",label:"شروع اعتبار",kind:"date"},{key:"valid_until",label:"پایان اعتبار",kind:"date"},
  {key:"status",label:"وضعیت",kind:"select",options:["pending","active","suspended","expired","cancelled"]},
  {key:"fee_status",label:"وضعیت شهریه",kind:"select",options:["unknown","unpaid","partial","paid","waived"]},{key:"notes",label:"یادداشت",kind:"long"}
 ]},
 {key:"staff",title:"مربیان و داوران",group:"نیروی انسانی",description:"پرونده مربی، داور، مربی بدنساز، سرپرست و عوامل اجرایی",fields:[
  {key:"member_id",label:"شناسه عضو",required:true},
  {key:"staff_role",label:"سمت",kind:"select",options:["coach","assistant_coach","referee","scorer","trainer","medical_staff","administrator","other"],required:true},
  {key:"license_number",label:"شماره مجوز"},{key:"grade",label:"درجه / سطح"},
  {key:"status",label:"وضعیت",kind:"select",options:["active","inactive","suspended"]},
  {key:"started_on",label:"تاریخ شروع",kind:"date"},{key:"ended_on",label:"تاریخ پایان",kind:"date"}
 ]},
 {key:"credentials",title:"مدارک و اعتبارنامه‌ها",group:"نیروی انسانی",description:"گواهینامه‌ها، درجات داوری و مربیگری و تاریخ انقضا",fields:[
  {key:"staff_profile_id",label:"شناسه پرونده فرد",required:true},{key:"credential_type",label:"نوع مدرک",required:true},
  {key:"title",label:"عنوان مدرک",required:true},{key:"issuer",label:"صادرکننده"},
  {key:"credential_number",label:"شماره مدرک"},{key:"issued_on",label:"تاریخ صدور",kind:"date"},
  {key:"expires_on",label:"تاریخ انقضا",kind:"date"}
 ]},
 {key:"guardian-consents",title:"رضایت والدین / سرپرست",group:"حفاظت ورزشکار",description:"ثبت رضایت‌های محدود به هدف، قابل پیگیری و قابل لغو",fields:[
  {key:"member_id",label:"شناسه ورزشکار",required:true},{key:"guardian_user_id",label:"شناسه حساب سرپرست",required:true},
  {key:"consent_scope",label:"دامنه رضایت",kind:"select",options:["membership","training","competition","travel","media","data_processing","talent_assessment"],required:true},
  {key:"status",label:"وضعیت",kind:"select",options:["pending","granted","revoked","expired"]},
  {key:"valid_from",label:"شروع اعتبار",kind:"datetime"},{key:"valid_until",label:"پایان اعتبار",kind:"datetime"},{key:"notes",label:"یادداشت",kind:"long"}
 ]},
 {key:"training-programs",title:"برنامه‌های آموزشی",group:"آموزش و رشد",description:"دوره‌ها، اردوها و برنامه‌های تمرینی رشته والیبال",fields:[
  {key:"title",label:"عنوان برنامه",required:true},{key:"sport_type",label:"رشته",required:true},
  {key:"age_group",label:"رده سنی"},{key:"target_group",label:"گروه هدف"},
  {key:"coach_profile_id",label:"شناسه مربی مسئول"},{key:"start_date",label:"شروع",kind:"date"},
  {key:"end_date",label:"پایان",kind:"date"},{key:"status",label:"وضعیت",kind:"select",options:["draft","active","completed","cancelled"]},
  {key:"description",label:"شرح برنامه",kind:"long"}
 ]},
 {key:"training-sessions",title:"جلسات تمرینی",group:"آموزش و رشد",description:"زمان‌بندی جلسات، مربی، محل و وضعیت برگزاری",fields:[
  {key:"program_id",label:"شناسه برنامه",required:true},{key:"title",label:"عنوان جلسه",required:true},
  {key:"starts_at",label:"شروع جلسه",kind:"datetime",required:true},{key:"ends_at",label:"پایان جلسه",kind:"datetime"},
  {key:"facility_id",label:"شناسه سالن"},{key:"coach_profile_id",label:"شناسه مربی"},
  {key:"status",label:"وضعیت",kind:"select",options:["scheduled","completed","cancelled"]},{key:"notes",label:"یادداشت",kind:"long"}
 ]},
 {key:"attendance",title:"حضور و غیاب",group:"آموزش و رشد",description:"ثبت حضور، غیبت، تأخیر و غیبت موجه",fields:[
  {key:"session_id",label:"شناسه جلسه",required:true},{key:"member_id",label:"شناسه عضو",required:true},
  {key:"attendance_status",label:"وضعیت حضور",kind:"select",options:["present","absent","late","excused"],required:true},
  {key:"notes",label:"یادداشت"}
 ]},
 {key:"assessments",title:"ارزیابی و استعدادیابی",group:"حفاظت ورزشکار",description:"ارزیابی اولیه و دوره‌ای با ثبت شاخص‌ها و تأیید کارشناس مجاز",fields:[
  {key:"member_id",label:"شناسه ورزشکار",required:true},{key:"sport_type",label:"رشته",required:true},
  {key:"assessment_type",label:"نوع ارزیابی",kind:"select",options:["initial","technical","physical","performance","talent","periodic","other"],required:true},
  {key:"assessed_on",label:"تاریخ ارزیابی",kind:"date"},{key:"assessor_profile_id",label:"شناسه ارزیاب"},{key:"guardian_consent_id",label:"شناسه رضایت معتبر سرپرست (برای استعدادیابی الزامی است)"},
  {key:"score",label:"امتیاز",kind:"number"},{key:"indicators",label:"شاخص‌ها (JSON)",kind:"json"},
  {key:"strengths",label:"نقاط قوت",kind:"long"},{key:"development_areas",label:"زمینه‌های قابل توسعه",kind:"long"},
  {key:"recommendation",label:"پیشنهاد تخصصی",kind:"long"}
 ]},
 {key:"development-plans",title:"پرونده مسیر رشد",group:"آموزش و رشد",description:"هدف‌ها، مربی مسئول، بازبینی و پیگیری پیشرفت",fields:[
  {key:"member_id",label:"شناسه ورزشکار",required:true},{key:"assessment_id",label:"شناسه ارزیابی"},
  {key:"title",label:"عنوان برنامه رشد",required:true},{key:"goals",label:"هدف‌ها (JSON آرایه)",kind:"json"},
  {key:"start_date",label:"شروع",kind:"date"},{key:"review_date",label:"تاریخ بازبینی",kind:"date"},
  {key:"assigned_coach_profile_id",label:"شناسه مربی مسئول"},{key:"guardian_consent_id",label:"شناسه رضایت سرپرست"},
  {key:"progress_notes",label:"گزارش پیشرفت",kind:"long"}
 ]},
 {key:"facilities",title:"اماکن و سالن‌ها",group:"اماکن و تجهیزات",description:"ثبت سالن، زمین، ظرفیت، وضعیت و دسترس‌پذیری",fields:[
  {key:"name",label:"نام مکان",required:true},{key:"facility_type",label:"نوع مکان",kind:"select",options:["sports_hall","volleyball_court","shooting_range","gym","outdoor_field","office","other"],required:true},
  {key:"address",label:"نشانی"},{key:"capacity",label:"ظرفیت",kind:"number"},
  {key:"status",label:"وضعیت",kind:"select",options:["active","maintenance","inactive"]},{key:"accessibility_notes",label:"توضیحات",kind:"long"}
 ]},
 {key:"bookings",title:"رزرو سالن",group:"اماکن و تجهیزات",description:"درخواست و تأیید زمان استفاده از اماکن",fields:[
  {key:"facility_id",label:"شناسه مکان",required:true},{key:"purpose",label:"هدف رزرو",required:true},
  {key:"starts_at",label:"شروع",kind:"datetime",required:true},{key:"ends_at",label:"پایان",kind:"datetime",required:true}
 ]},
 {key:"invoices",title:"شهریه و صورتحساب",group:"مالی و بیمه",description:"صدور صورتحساب و پیگیری بدهی با مبالغ بر حسب واحد خرد ارز",fields:[
  {key:"member_id",label:"شناسه عضو",required:true},{key:"membership_id",label:"شناسه عضویت"},
  {key:"invoice_number",label:"شماره صورتحساب",required:true},{key:"description",label:"شرح",required:true},
  {key:"amount_minor",label:"مبلغ (ریال)",kind:"number",required:true},{key:"currency",label:"ارز",kind:"select",options:["IRR","USD"]},
  {key:"due_date",label:"سررسید",kind:"date"}
 ]},
 {key:"payments",title:"ثبت پرداخت",group:"مالی و بیمه",description:"ثبت پرداخت و تأیید وضعیت وصول؛ اطلاعات کارت بانکی ذخیره نمی‌شود",fields:[
  {key:"invoice_id",label:"شناسه صورتحساب",required:true},{key:"amount_minor",label:"مبلغ (ریال)",kind:"number",required:true},
  {key:"payment_method",label:"روش پرداخت",kind:"select",options:["cash","bank_transfer","gateway","other"],required:true},
  {key:"external_reference",label:"شناسه پیگیری"},{key:"currency",label:"ارز",kind:"select",options:["IRR","USD"]},{key:"notes",label:"یادداشت",kind:"long"}
 ]},
 {key:"insurance",title:"بیمه ورزشکاران",group:"مالی و بیمه",description:"وضعیت پوشش، اعتبار، تأیید و تمدید بیمه",fields:[
  {key:"member_id",label:"شناسه عضو",required:true},{key:"provider",label:"شرکت بیمه"},
  {key:"policy_number",label:"شماره بیمه‌نامه"},{key:"coverage_type",label:"نوع پوشش",required:true},
  {key:"valid_from",label:"شروع اعتبار",kind:"date"},{key:"valid_until",label:"پایان اعتبار",kind:"date"},
  {key:"insurance_status",label:"وضعیت",kind:"select",options:["pending","active","expired","cancelled","rejected"]}
 ]},
 {key:"announcements",title:"اطلاعیه‌ها",group:"ارتباطات",description:"اطلاع‌رسانی هدفمند به ورزشکاران، مربیان، داوران و سرپرستان",fields:[
  {key:"title",label:"عنوان",required:true},{key:"body",label:"متن اطلاعیه",kind:"long",required:true},
  {key:"audience",label:"مخاطب",kind:"select",options:["all","athletes","coaches","referees","staff","guardians"]},
  {key:"publish_at",label:"زمان انتشار",kind:"datetime"},{key:"expires_at",label:"انقضا",kind:"datetime"}
 ]},
 {key:"settings",title:"تنظیمات سازمان",group:"مدیریت هیئت",description:"تنظیمات نسخه‌دار و محدود به سازمان فعال",fields:[
  {key:"setting_scope",label:"دامنه",kind:"select",options:["tenant","org_unit","sport_module"]},
  {key:"setting_key",label:"کلید تنظیم",required:true},{key:"setting_value",label:"مقدار (JSON)",kind:"json",required:true},
  {key:"version",label:"نسخه",kind:"number"},{key:"effective_from",label:"زمان اجرا",kind:"datetime"}
 ]}
];

function labelOf(row:RecordRow) {
  return String(row.name ?? row.title ?? row.invoice_number ?? row.membership_number ?? row.id ?? "رکورد");
}

export default function VolleyballOperationsPage() {
 const [resourceKey,setResourceKey]=useState("org-units");
 const [items,setItems]=useState<RecordRow[]>([]);
 const [values,setValues]=useState<Record<string,string>>({});
 const [busy,setBusy]=useState(false);
 const [message,setMessage]=useState("");
 const selected=useMemo(()=>RESOURCES.find(r=>r.key===resourceKey)??RESOURCES[0],[resourceKey]);
 const grouped=useMemo(()=>Array.from(new Set(RESOURCES.map(r=>r.group))),[]);

 const load=useCallback(async(key:string)=>{
  setBusy(true);setMessage("");
  try{
   const response=await fetch("/api/sports/operations/"+key,{cache:"no-store"});
   const payload=await response.json() as {items?:RecordRow[];error?:string};
   if(!response.ok)throw new Error(payload.error??"دریافت اطلاعات ناموفق بود.");
   setItems(payload.items??[]);
  }catch(error){setItems([]);setMessage(error instanceof Error?error.message:"خطای دریافت اطلاعات");}
  finally{setBusy(false);}
 },[]);

 useEffect(()=>{void load(resourceKey);setValues({});},[resourceKey,load]);

 function setField(key:string,value:string){setValues(current=>({...current,[key]:value}));}
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();setBusy(true);setMessage("");
  try{
   const payload:Record<string,unknown>={};
   for(const field of selected.fields){
    const raw=values[field.key]??"";
    if(raw==="")continue;
    if(field.kind==="number")payload[field.key]=Number(raw);
    else if(field.kind==="json")payload[field.key]=JSON.parse(raw);
    else if(field.kind==="datetime")payload[field.key]=new Date(raw).toISOString();\n    else payload[field.key]=raw;
   }
   const response=await fetch("/api/sports/operations/"+selected.key,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(payload)});
   const result=await response.json() as {error?:string};
   if(!response.ok)throw new Error(result.error??"ثبت اطلاعات ناموفق بود.");
   setValues({});
   setMessage("اطلاعات با موفقیت ثبت شد.");
   await load(selected.key);
  }catch(error){setMessage(error instanceof Error?error.message:"اطلاعات ورودی معتبر نیست.");}
  finally{setBusy(false);}
 }

 return <main className="shell grid">
  <header className="topbar"><div className="shell topbar-inner">
   <div><div className="brand">METATYA SPORT OS · VOLLEYBALL</div><small>مرکز عملیات یکپارچه هیئت والیبال</small></div>
   <Link className="btn secondary" href="/volleyball">بازگشت به پنل والیبال</Link>
  </div></header>
  <section><h1 className="page-heading">مدیریت جامع هیئت والیبال</h1>
   <p className="muted">همه بخش‌ها در یک سازمان فعال و با کنترل دسترسی سمت سرور مدیریت می‌شوند. داده‌ها بین سازمان‌ها جدا هستند.</p></section>
  <section className="panel">
   <h2 className="section-title">حوزه‌های عملیاتی</h2>
   {grouped.map(group=><div key={group} className="grid">
    <h3>{group}</h3>
    <div className="form-grid">
     {RESOURCES.filter(r=>r.group===group).map(r=><button key={r.key} type="button" className={r.key===resourceKey?"btn":"btn secondary"} onClick={()=>setResourceKey(r.key)}>{r.title}</button>)}
    </div>
   </div>)}
  </section>
  <section className="panel">
   <h2 className="section-title">{selected.title}</h2>
   <p className="muted">{selected.description}</p>
   <form className="form-grid" onSubmit={submit}>
    {selected.fields.map(field=><div className="field" key={field.key}>
     <label htmlFor={"field-"+field.key}>{field.label}{field.required?" *":""}</label>
     {field.kind==="long"||field.kind==="json"?
      <textarea id={"field-"+field.key} required={field.required} rows={field.kind==="json"?4:3} value={values[field.key]??""} onChange={e=>setField(field.key,e.target.value)} placeholder={field.kind==="json"?(field.key==="goals"?"[]":"{}"):field.hint??""}/>:
      field.kind==="select"?
       <select id={"field-"+field.key} required={field.required} value={values[field.key]??""} onChange={e=>setField(field.key,e.target.value)}>
        <option value="">انتخاب کنید</option>{(field.options??[]).map(option=><option key={option} value={option}>{option}</option>)}
       </select>:
       <input id={"field-"+field.key} required={field.required} type={field.kind==="number"?"number":field.kind==="date"?"date":field.kind==="datetime"?"datetime-local":"text"} value={values[field.key]??""} onChange={e=>setField(field.key,e.target.value)} placeholder={field.hint??(field.key.endsWith("_id")?"UUID رکورد مرتبط": "")}/>
     }
    </div>)}
    <div className="field full"><button className="btn" disabled={busy}>{busy?"در حال پردازش...":"ثبت "+selected.title}</button></div>
   </form>
   {message&&<p className="status" role="status">{message}</p>}
  </section>
  <section className="panel">
   <div className="topbar-inner"><h2 className="section-title">سوابق ثبت‌شده</h2><button className="btn secondary" disabled={busy} onClick={()=>void load(selected.key)}>بروزرسانی</button></div>
   {items.length===0?<p className="muted">رکوردی برای نمایش وجود ندارد یا دسترسی این نقش محدود است.</p>:
    <ul className="list">{items.map((item,index)=><li key={String(item.id??index)}>
     <strong>{labelOf(item)}</strong>
     <div className="muted">{Object.entries(item).filter(([key])=>!["id","tenant_id","created_at","updated_at"].includes(key)).slice(0,5).map(([key,value])=>key+": "+(typeof value==="object"?JSON.stringify(value):String(value??"—"))).join(" · ")}</div>
     <small className="muted">شناسه: {String(item.id??"—")}</small>
    </li>)}</ul>}
  </section>
  <p className="muted">نکته: این پنل، عملیات ثبت و مشاهدهٔ منابع جدید را پوشش می‌دهد. شناسهٔ رکوردهای مرتبط باید از فهرست همان بخش برداشته شود. گردش‌های حساس مانند تأیید مالی، اعتبارنامه و رضایت سرپرست در API محدود به نقش‌های مجاز هستند.</p>
 </main>;
}
