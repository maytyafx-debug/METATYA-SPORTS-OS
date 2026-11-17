"use client";
import {FormEvent,useCallback,useEffect,useState} from "react";
import {useRouter} from "next/navigation";
import {createSupabaseBrowserClient} from "@/lib/supabase/client";
type Membership={tenant_id:string;role:string;sports_tenants:{id:string;name:string;slug:string}|null};
type Member={id:string;full_name:string;sport_type:string|null;status:string};
type SportEvent={id:string;title:string;sport_type:string|null;event_date:string;location:string|null;status:string};
type Payload={error?:string;members?:Member[];events?:SportEvent[]};
export default function DashboardPage(){
 const router=useRouter();const[ready,setReady]=useState(false);const[busy,setBusy]=useState(false);
 const[memberships,setMemberships]=useState<Membership[]>([]);const[tenantId,setTenantId]=useState("");
 const[members,setMembers]=useState<Member[]>([]);const[events,setEvents]=useState<SportEvent[]>([]);
 const[memberName,setMemberName]=useState("");const[sportType,setSportType]=useState("والیبال");
 const[eventTitle,setEventTitle]=useState("");const[eventDate,setEventDate]=useState("");const[message,setMessage]=useState("");
 const apiFetch=useCallback(async(path:string,init:RequestInit={})=>{
  if(!tenantId)throw new Error("ابتدا سازمان فعال را انتخاب کنید.");
  const headers=new Headers(init.headers);headers.set("x-tenant-id",tenantId);if(init.body)headers.set("Content-Type","application/json");
  const response=await fetch(path,{...init,headers,cache:"no-store"});const payload=await response.json() as Payload;
  if(response.status===401){router.replace("/login");throw new Error("نشست شما منقضی شده است.");}
  if(!response.ok)throw new Error(payload.error||"درخواست ناموفق بود.");return payload;
 },[tenantId,router]);
 const loadData=useCallback(async()=>{const[m,e]=await Promise.all([apiFetch("/api/sports/members"),apiFetch("/api/sports/events")]);setMembers(m.members??[]);setEvents(e.events??[]);},[apiFetch]);
 useEffect(()=>{let active=true;async function init(){try{
  const supabase=createSupabaseBrowserClient();const{data:{user}}=await supabase.auth.getUser();if(!user){router.replace("/login");return;}
  const{data,error}=await supabase.from("sports_tenant_memberships").select("tenant_id,role,sports_tenants(id,name,slug)").eq("user_id",user.id).eq("status","active");
  if(error)throw error;if(!data?.length){setMessage("حساب شما هنوز به هیچ سازمان فعالی متصل نشده است.");return;}
  const rows=data as unknown as Membership[];if(active){setMemberships(rows);if(rows.length===1)setTenantId(rows[0].tenant_id);}
 }catch(err){if(active)setMessage(err instanceof Error?err.message:"خطای ارتباط با سرویس");}finally{if(active)setReady(true);}}
 void init();return()=>{active=false;};},[router]);
 useEffect(()=>{if(!tenantId)return;let active=true;void loadData().catch(err=>{if(active)setMessage(err instanceof Error?err.message:"خطای دریافت اطلاعات");});return()=>{active=false;};},[tenantId,loadData]);
 async function post(path:string,body:unknown){return apiFetch(path,{method:"POST",body:JSON.stringify(body)});}
 async function submitMember(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage("");try{await post("/api/sports/members",{full_name:memberName,sport_type:sportType});setMemberName("");await loadData();setMessage("عضو با موفقیت ثبت شد.");}catch(err){setMessage(err instanceof Error?err.message:"ثبت عضو ناموفق بود.");}finally{setBusy(false);}}
 async function submitEvent(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage("");try{await post("/api/sports/events",{title:eventTitle,sport_type:sportType,event_date:new Date(eventDate).toISOString()});setEventTitle("");setEventDate("");await loadData();setMessage("رویداد با موفقیت ثبت شد.");}catch(err){setMessage(err instanceof Error?err.message:"ثبت رویداد ناموفق بود.");}finally{setBusy(false);}}
 async function signOut(){await createSupabaseBrowserClient().auth.signOut();router.replace("/login");router.refresh();}
 if(!ready)return <main className="shell"><p>در حال بارگذاری پنل...</p></main>;
 const selected=memberships.find(m=>m.tenant_id===tenantId);
 return <><header className="topbar"><div className="shell topbar-inner"><div><div className="brand">METATYA Sports OS</div><small>سامانه عمومی مدیریت باشگاه‌های ورزشی</small></div><button className="btn secondary" onClick={signOut}>خروج</button></div></header>
 <main className="shell grid"><section><h1 className="page-heading">داشبورد مدیریتی</h1><p className="muted">مدیریت اعضا و رویدادهای باشگاه</p></section>
 {memberships.length>1&&<section className="panel field"><label htmlFor="tenant">سازمان فعال</label><select id="tenant" value={tenantId} onChange={e=>{setMembers([]);setEvents([]);setTenantId(e.target.value);}}><option value="">انتخاب سازمان</option>{memberships.map(m=><option key={m.tenant_id} value={m.tenant_id}>{m.sports_tenants?.name??m.tenant_id} — {m.role}</option>)}</select></section>}
 {selected&&<p className="muted">سازمان: {selected.sports_tenants?.name??"سازمان انتخاب‌شده"} | نقش: {selected.role}</p>}
 {tenantId&&<><section className="stats"><div className="stat"><span className="muted">اعضا</span><strong>{members.length}</strong></div><div className="stat"><span className="muted">رویدادها</span><strong>{events.length}</strong></div></section>
 <section className="panel"><h2 className="section-title">ثبت عضو جدید</h2><form className="form-grid" onSubmit={submitMember}><div className="field"><label htmlFor="member-name">نام عضو</label><input id="member-name" required maxLength={150} value={memberName} onChange={e=>setMemberName(e.target.value)}/></div><div className="field"><label htmlFor="sport-type">رشته ورزشی</label><input id="sport-type" value={sportType} onChange={e=>setSportType(e.target.value)}/></div><div className="field full"><button className="btn" disabled={busy}>ثبت عضو</button></div></form></section>
 <section className="panel"><h2 className="section-title">ثبت رویداد</h2><form className="form-grid" onSubmit={submitEvent}><div className="field"><label htmlFor="event-title">عنوان رویداد</label><input id="event-title" required maxLength={200} value={eventTitle} onChange={e=>setEventTitle(e.target.value)}/></div><div className="field"><label htmlFor="event-date">تاریخ و ساعت</label><input id="event-date" type="datetime-local" required value={eventDate} onChange={e=>setEventDate(e.target.value)}/></div><div className="field full"><button className="btn" disabled={busy}>ثبت رویداد</button></div></form></section>
 <section className="panel"><h2 className="section-title">فهرست اعضا</h2>{members.length===0?<p className="muted">عضوی ثبت نشده است.</p>:<ul className="list">{members.map(m=><li key={m.id}>{m.full_name}<span className="muted"> — {m.sport_type??"رشته ثبت نشده"}</span></li>)}</ul>}</section>
 <section className="panel"><h2 className="section-title">رویدادها</h2>{events.length===0?<p className="muted">رویدادی ثبت نشده است.</p>:<ul className="list">{events.map(v=><li key={v.id}>{v.title} — {new Date(v.event_date).toLocaleDateString("fa-IR")}</li>)}</ul>}</section></>}
 {message&&<p className="status" role="status" aria-live="polite">{message}</p>}</main></>;
}
