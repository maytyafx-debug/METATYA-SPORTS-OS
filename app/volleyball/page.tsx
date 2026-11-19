"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { validateVolleyballMatchScore, type VolleyballSetScore } from "@/lib/sports/volleyball/scoring";

type Membership = { tenant_id: string; role: string; sports_tenants: { id: string; name: string; slug: string } | null };
type Member = { id: string; full_name: string; sport_type: string | null; status: string };
type Team = { id: string; name: string; gender: string; age_group: string | null; category: string | null; season: string | null; home_venue: string | null; status: string };
type Competition = { id: string; name: string; format: string; season: string | null; status: string; start_date: string | null; end_date: string | null };
type Match = { id: string; competition_id: string | null; home_team_id: string; away_team_id: string; scheduled_at: string; venue: string | null; best_of: 3 | 5; status: string; result_status: string; approved_at: string | null };
type MatchSet = { match_id: string; set_number: number; home_points: number; away_points: number };
type Player = { id: string; member_id: string; jersey_number: number | null; position: string; is_captain: boolean; sports_members: { full_name: string } | null };
type ApiPayload = { error?: string; details?: string[]; memberships?: Membership[]; teams?: Team[]; team?: Team; competitions?: Competition[]; competition?: Competition; matches?: Match[]; sets?: MatchSet[]; members?: Member[]; players?: Player[]; ok?: boolean; result_status?: string };

const positionNames: Record<string, string> = {
  setter: "پاسور", outside_hitter: "دریافت‌کننده قدرتی", opposite: "پشت‌خط‌زن",
  middle_blocker: "سرعتی‌زن", libero: "لیبرو", defensive_specialist: "مدافع تخصصی", unassigned: "تعیین‌نشده",
};
const statusNames: Record<string, string> = { scheduled: "برنامه‌ریزی‌شده", live: "در حال برگزاری", completed: "پایان‌یافته", cancelled: "لغوشده", pending: "در انتظار نتیجه", submitted: "ارسال‌شده برای تأیید", approved: "تأییدشده", rejected: "نیازمند اصلاح" };

export default function VolleyballPage() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [tenantId, setTenantId] = useState("");
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [teams, setTeams] = useState<Team[]>([]);
  const [competitions, setCompetitions] = useState<Competition[]>([]);
  const [matches, setMatches] = useState<Match[]>([]);
  const [sets, setSets] = useState<MatchSet[]>([]);
  const [players, setPlayers] = useState<Player[]>([]);
  const [selectedTeam, setSelectedTeam] = useState("");
  const [selectedMatch, setSelectedMatch] = useState("");
  const [selectedCompetition, setSelectedCompetition] = useState("");
  const [competitionName, setCompetitionName] = useState("");
  const [competitionFormat, setCompetitionFormat] = useState("league");
  const [competitionSeason, setCompetitionSeason] = useState("");
  const [competitionStart, setCompetitionStart] = useState("");
  const [competitionEnd, setCompetitionEnd] = useState("");
  const [registrationTeam, setRegistrationTeam] = useState("");
  const [poolCode, setPoolCode] = useState("");
  const [seed, setSeed] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [teamName, setTeamName] = useState("");
  const [gender, setGender] = useState("mixed");
  const [ageGroup, setAgeGroup] = useState("");
  const [category, setCategory] = useState("");
  const [season, setSeason] = useState("");
  const [homeVenue, setHomeVenue] = useState("");
  const [rosterMember, setRosterMember] = useState("");
  const [jersey, setJersey] = useState("");
  const [position, setPosition] = useState("unassigned");
  const [captain, setCaptain] = useState(false);
  const [homeTeam, setHomeTeam] = useState("");
  const [awayTeam, setAwayTeam] = useState("");
  const [scheduledAt, setScheduledAt] = useState("");
  const [matchVenue, setMatchVenue] = useState("");
  const [bestOf, setBestOf] = useState<3 | 5>(5);
  const [scoreSets, setScoreSets] = useState<VolleyballSetScore[]>([{home:0,away:0},{home:0,away:0},{home:0,away:0}]);

  const apiFetch = useCallback(async (path: string, init: RequestInit = {}): Promise<ApiPayload> => {
    if (!tenantId) throw new Error("ابتدا سازمان فعال را انتخاب کنید.");
    const headers = new Headers(init.headers);
    headers.set("x-tenant-id", tenantId);
    if (init.body) headers.set("Content-Type", "application/json");
    const response = await fetch(path, { ...init, headers, cache: "no-store" });
    const payload = await response.json() as ApiPayload;
    if (response.status === 401) { router.replace("/login"); throw new Error("نشست شما منقضی شده است."); }
    if (!response.ok) throw new Error(payload.error || "درخواست ناموفق بود.");
    return payload;
  }, [tenantId, router]);

  const load = useCallback(async () => {
    const [t, m, p, co] = await Promise.all([
      apiFetch("/api/sports/volleyball/teams"),
      apiFetch("/api/sports/volleyball/matches"),
      apiFetch("/api/sports/members"),
      apiFetch("/api/sports/volleyball/competitions"),
    ]);
    setTeams(t.teams ?? []); setMatches(m.matches ?? []); setSets(m.sets ?? []);
    setMembers(p.members ?? []); setCompetitions(co.competitions ?? []);
  }, [apiFetch]);

  useEffect(() => {
    let active = true;
    async function init() {
      try {
        const supabase = createSupabaseBrowserClient();
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) { router.replace("/login"); return; }
        const { data, error } = await supabase.from("sports_tenant_memberships")
          .select("tenant_id,role,sports_tenants(id,name,slug)").eq("user_id", user.id).eq("status", "active");
        if (error) throw error;
        const rows = (data ?? []) as unknown as Membership[];
        if (!rows.length) { if (active) setMessage("حساب شما به سازمان فعالی متصل نیست."); return; }
        if (active) { setMemberships(rows); if (rows.length === 1) setTenantId(rows[0].tenant_id); }
      } catch (e) { if (active) setMessage(e instanceof Error ? e.message : "خطای ورود"); }
      finally { if (active) setReady(true); }
    }
    void init();
    return () => { active = false; };
  }, [router]);

  useEffect(() => {
    if (!tenantId) return;
    let active = true;
    void load().catch(e => { if (active) setMessage(e instanceof Error ? e.message : "دریافت اطلاعات ناموفق بود."); });
    return () => { active = false; };
  }, [tenantId, load]);

  useEffect(() => {
    if (!tenantId || !selectedTeam) { setPlayers([]); return; }
    let active = true;
    void apiFetch(`/api/sports/volleyball/teams/${selectedTeam}/members`)
      .then(p => { if (active) setPlayers(p.players ?? []); })
      .catch(e => { if (active) setMessage(e instanceof Error ? e.message : "دریافت فهرست تیم ناموفق بود."); });
    return () => { active = false; };
  }, [tenantId, selectedTeam, apiFetch]);

  const chosenMatch = matches.find(m => m.id === selectedMatch);
  const validation = useMemo(() => chosenMatch ? validateVolleyballMatchScore({sets: scoreSets, bestOf: chosenMatch.best_of}) : null, [chosenMatch, scoreSets]);
  const teamNameOf = (id: string) => teams.find(t => t.id === id)?.name ?? "تیم";
  const setRows = (matchId: string) => sets.filter(s => s.match_id === matchId).sort((a,b) => a.set_number-b.set_number);

  async function submit(path: string, body: unknown, method = "POST") {
    setBusy(true); setMessage("");
    try { await apiFetch(path, { method, body: JSON.stringify(body) }); await load(); setMessage("اطلاعات با موفقیت ثبت شد."); }
    catch (e) { setMessage(e instanceof Error ? e.message : "عملیات ناموفق بود."); }
    finally { setBusy(false); }
  }
  async function createTeam(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    await submit("/api/sports/volleyball/teams", {name:teamName,gender,age_group:ageGroup,category,season,home_venue:homeVenue});
    setTeamName(""); setAgeGroup(""); setCategory(""); setSeason(""); setHomeVenue("");
  }
  async function addPlayer(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!selectedTeam) return;
    await submit(`/api/sports/volleyball/teams/${selectedTeam}/members`, {member_id:rosterMember,jersey_number:jersey,position,is_captain:captain});
    setRosterMember(""); setJersey(""); setCaptain(false);
    const p = await apiFetch(`/api/sports/volleyball/teams/${selectedTeam}/members`).catch(() => null);
    setPlayers(p?.players ?? []);
  }
  async function createCompetition(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    await submit("/api/sports/volleyball/competitions", {
      name:competitionName, format:competitionFormat, season:competitionSeason,
      start_date:competitionStart || null, end_date:competitionEnd || null,
    });
    setCompetitionName(""); setCompetitionSeason(""); setCompetitionStart(""); setCompetitionEnd("");
  }
  async function registerTeam(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!selectedCompetition) return;
    await submit("/api/sports/volleyball/competitions/" + selectedCompetition + "/teams", {
      team_id:registrationTeam, pool_code:poolCode, seed:seed || null,
    });
    setRegistrationTeam(""); setPoolCode(""); setSeed("");
  }
  async function createMatch(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    await submit("/api/sports/volleyball/matches", {home_team_id:homeTeam,away_team_id:awayTeam,competition_id:selectedCompetition || null,scheduled_at:new Date(scheduledAt).toISOString(),venue:matchVenue,best_of:bestOf});
    setHomeTeam(""); setAwayTeam(""); setScheduledAt(""); setMatchVenue("");
  }
  async function sendScore(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!chosenMatch || !validation || validation.valid === false) {
      setMessage(validation && validation.valid === false ? validation.errors.join("، ") : "مسابقه را انتخاب کنید.");
      return;
    }
    await submit(`/api/sports/volleyball/matches/${chosenMatch.id}/score`, {sets:scoreSets});
  }
  async function decide(matchId: string, decision: "approved" | "rejected") {
    await submit(`/api/sports/volleyball/matches/${matchId}/score`, {decision}, "PATCH");
  }
  async function signOut() { await createSupabaseBrowserClient().auth.signOut(); router.replace("/login"); router.refresh(); }

  if (!ready) return <main className="shell"><p>در حال بارگذاری پنل والیبال...</p></main>;
  const selectedMembership = memberships.find(m => m.tenant_id === tenantId);
  return <>
    <header className="topbar"><div className="shell topbar-inner">
      <div><div className="brand">METATYA EXPERT OS · VOLLEYBALL</div><small>ماژول والیبال در سامانه جامع Sports OS</small></div>
      <div className="topbar-inner"><Link className="btn secondary" href="/">داشبورد مادر</Link><button className="btn secondary" onClick={signOut}>خروج</button></div>
    </div></header>
    <main className="shell grid">
      <section><h1 className="page-heading">مدیریت والیبال</h1><p className="muted">باشگاه، تیم‌ها، فهرست بازیکنان، برنامه مسابقات و ثبت و تأیید نتایج</p></section>
      {memberships.length > 1 && <section className="panel field"><label htmlFor="tenant">سازمان فعال</label><select id="tenant" value={tenantId} onChange={e=>{setTenantId(e.target.value);setTeams([]);setMatches([]);setSets([]);setPlayers([]);setCompetitions([]);}}><option value="">انتخاب سازمان</option>{memberships.map(m=><option key={m.tenant_id} value={m.tenant_id}>{m.sports_tenants?.name ?? m.tenant_id} — {m.role}</option>)}</select></section>}
      {selectedMembership && <p className="muted">سازمان: {selectedMembership.sports_tenants?.name ?? "سازمان فعال"} | نقش: {selectedMembership.role}</p>}
      {message && <section className="panel status" role="status"><p>{message}</p></section>}
      {!tenantId && memberships.length > 1 && <section className="panel"><p>برای مشاهده اطلاعات، سازمان فعال را انتخاب کنید.</p></section>}
      {tenantId && <>
        <section className="stats">
          <div className="stat"><span className="muted">تیم‌های والیبال</span><strong>{teams.length}</strong></div>
          <div className="stat"><span className="muted">مسابقات ثبت‌شده</span><strong>{matches.length}</strong></div>
          <div className="stat"><span className="muted">نتایج نیازمند بررسی</span><strong>{matches.filter(m=>m.result_status==="submitted").length}</strong></div>
        </section>
        <section className="panel"><h2 className="section-title">۱. ساخت تیم</h2>
          <form className="form-grid" onSubmit={createTeam}>
            <div className="field"><label>نام تیم</label><input required minLength={2} maxLength={140} value={teamName} onChange={e=>setTeamName(e.target.value)} /></div>
            <div className="field"><label>رده جنسیتی</label><select value={gender} onChange={e=>setGender(e.target.value)}><option value="women">بانوان</option><option value="men">آقایان</option><option value="mixed">مختلط</option></select></div>
            <div className="field"><label>رده سنی</label><input value={ageGroup} maxLength={50} onChange={e=>setAgeGroup(e.target.value)} placeholder="مثلاً نوجوانان" /></div>
            <div className="field"><label>سطح / دسته</label><input value={category} maxLength={60} onChange={e=>setCategory(e.target.value)} placeholder="مثلاً لیگ استان" /></div>
            <div className="field"><label>فصل ورزشی</label><input value={season} maxLength={30} onChange={e=>setSeason(e.target.value)} placeholder="مثلاً ۱۴۰۵-۱۴۰۶" /></div>
            <div className="field"><label>سالن خانگی</label><input value={homeVenue} maxLength={180} onChange={e=>setHomeVenue(e.target.value)} /></div>
            <div className="field full"><button className="btn" disabled={busy}>ثبت تیم</button></div>
          </form>
          <ul className="list">{teams.map(t=><li key={t.id}><strong>{t.name}</strong> — {t.gender==="women"?"بانوان":t.gender==="men"?"آقایان":"مختلط"} {t.age_group ? `· ${t.age_group}` : ""} {t.season ? `· ${t.season}` : ""}</li>)}</ul>
        </section>
        <section className="panel"><h2 className="section-title">۲. مدیریت فهرست بازیکنان</h2>
          {teams.length===0 ? <p className="muted">ابتدا یک تیم بسازید.</p> : <>
            <div className="field"><label>تیم</label><select value={selectedTeam} onChange={e=>setSelectedTeam(e.target.value)}><option value="">انتخاب تیم</option>{teams.map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></div>
            {selectedTeam && <><form className="form-grid" onSubmit={addPlayer}>
              <div className="field"><label>ورزشکار از اعضای سازمان</label><select required value={rosterMember} onChange={e=>setRosterMember(e.target.value)}><option value="">انتخاب ورزشکار</option>{members.map(m=><option key={m.id} value={m.id}>{m.full_name}</option>)}</select></div>
              <div className="field"><label>شماره پیراهن</label><input type="number" min="1" max="99" value={jersey} onChange={e=>setJersey(e.target.value)} /></div>
              <div className="field"><label>پست تخصصی</label><select value={position} onChange={e=>setPosition(e.target.value)}>{Object.entries(positionNames).map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></div>
              <label className="field"><span>کاپیتان تیم</span><input type="checkbox" checked={captain} onChange={e=>setCaptain(e.target.checked)} /></label>
              <div className="field full"><button className="btn" disabled={busy || !rosterMember}>افزودن به فهرست تیم</button></div>
            </form>
            <ul className="list">{players.map(p=><li key={p.id}>#{p.jersey_number ?? "—"} {p.sports_members?.full_name ?? "ورزشکار"} — {positionNames[p.position] ?? p.position} {p.is_captain ? "· کاپیتان" : ""}</li>)}</ul>
            {players.length===0 && <p className="muted">برای این تیم هنوز بازیکنی ثبت نشده است.</p>}</>}
          </>}
        </section>
        <section className="panel"><h2 className="section-title">۳. مدیریت رقابت‌ها و لیگ‌ها</h2>
          <form className="form-grid" onSubmit={createCompetition}>
            <div className="field"><label>عنوان رقابت</label><input required minLength={2} maxLength={160} value={competitionName} onChange={e=>setCompetitionName(e.target.value)} /></div>
            <div className="field"><label>قالب رقابت</label><select value={competitionFormat} onChange={e=>setCompetitionFormat(e.target.value)}><option value="league">لیگ</option><option value="cup">جام حذفی</option><option value="round_robin">دوره‌ای</option><option value="friendly">دوستانه</option><option value="tournament">تورنمنت</option></select></div>
            <div className="field"><label>فصل</label><input maxLength={30} value={competitionSeason} onChange={e=>setCompetitionSeason(e.target.value)} placeholder="۱۴۰۵-۱۴۰۶" /></div>
            <div className="field"><label>تاریخ شروع</label><input type="date" value={competitionStart} onChange={e=>setCompetitionStart(e.target.value)} /></div>
            <div className="field"><label>تاریخ پایان</label><input type="date" value={competitionEnd} onChange={e=>setCompetitionEnd(e.target.value)} /></div>
            <div className="field full"><button className="btn" disabled={busy}>ایجاد رقابت</button></div>
          </form>
          {competitions.length>0 && <><div className="field"><label>رقابت فعال برای ثبت تیم</label><select value={selectedCompetition} onChange={e=>setSelectedCompetition(e.target.value)}><option value="">انتخاب رقابت</option>{competitions.map(co=><option key={co.id} value={co.id}>{co.name} · {co.season ?? co.format}</option>)}</select></div>
          {selectedCompetition && <form className="form-grid" onSubmit={registerTeam}>
            <div className="field"><label>تیم</label><select required value={registrationTeam} onChange={e=>setRegistrationTeam(e.target.value)}><option value="">انتخاب تیم</option>{teams.map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></div>
            <div className="field"><label>گروه</label><input value={poolCode} maxLength={20} onChange={e=>setPoolCode(e.target.value)} placeholder="A / B" /></div>
            <div className="field"><label>سید</label><input type="number" min="1" max="999" value={seed} onChange={e=>setSeed(e.target.value)} /></div>
            <div className="field"><button className="btn" disabled={busy || !registrationTeam}>ثبت تیم در رقابت</button></div>
          </form>}</>}
          <ul className="list">{competitions.map(co=><li key={co.id}><strong>{co.name}</strong> — {co.format} · {co.season ?? "بدون فصل"} · {co.status}</li>)}</ul>
        </section>
        <section className="panel"><h2 className="section-title">۴. برنامه‌ریزی مسابقه</h2>
          {teams.length<2 ? <p className="muted">برای برنامه‌ریزی مسابقه حداقل دو تیم لازم است.</p> : <form className="form-grid" onSubmit={createMatch}>
            <div className="field"><label>تیم میزبان</label><select required value={homeTeam} onChange={e=>setHomeTeam(e.target.value)}><option value="">انتخاب تیم</option>{teams.map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></div>
            <div className="field"><label>تیم میهمان</label><select required value={awayTeam} onChange={e=>setAwayTeam(e.target.value)}><option value="">انتخاب تیم</option>{teams.filter(t=>t.id!==homeTeam).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></div>
            <div className="field"><label>تاریخ و ساعت</label><input required type="datetime-local" value={scheduledAt} onChange={e=>setScheduledAt(e.target.value)} /></div>
            <div className="field"><label>سالن / محل مسابقه</label><input value={matchVenue} maxLength={180} onChange={e=>setMatchVenue(e.target.value)} /></div>
            <div className="field"><label>رقابت (اختیاری)</label><select value={selectedCompetition} onChange={e=>setSelectedCompetition(e.target.value)}><option value="">مسابقه مستقل</option>{competitions.map(co=><option key={co.id} value={co.id}>{co.name}</option>)}</select></div>
            <div className="field"><label>فرمت مسابقه</label><select value={bestOf} onChange={e=>setBestOf(Number(e.target.value) as 3|5)}><option value={5}>۳ برد از ۵ ست</option><option value={3}>۲ برد از ۳ ست</option></select></div>
            <div className="field full"><button className="btn" disabled={busy || !homeTeam || !awayTeam || homeTeam===awayTeam}>ثبت مسابقه</button></div>
          </form>}
        </section>
        <section className="panel"><h2 className="section-title">۵. مسابقات و نتایج</h2>
          {matches.length===0 ? <p className="muted">مسابقه‌ای ثبت نشده است.</p> : <ul className="list">{matches.map(m=><li key={m.id}>
            <strong>{teamNameOf(m.home_team_id)} — {teamNameOf(m.away_team_id)}</strong>
            <div className="muted">{new Date(m.scheduled_at).toLocaleString("fa-IR")} · {m.venue ?? "محل تعیین نشده"} · {m.best_of} ستی</div>
            <div>{statusNames[m.status] ?? m.status} · وضعیت نتیجه: {statusNames[m.result_status] ?? m.result_status}</div>
            <div>{setRows(m.id).map(s=><span key={s.set_number} style={{marginInlineEnd:10}}>ست {s.set_number}: {s.home_points}-{s.away_points}</span>)}</div>
            {m.result_status==="submitted" && <div className="topbar-inner" style={{justifyContent:"flex-start",marginTop:8}}><button className="btn" disabled={busy} onClick={()=>void decide(m.id,"approved")}>تأیید نتیجه</button><button className="btn secondary" disabled={busy} onClick={()=>void decide(m.id,"rejected")}>درخواست اصلاح</button></div>}
          </li>)}</ul>}
        </section>
        <section className="panel"><h2 className="section-title">۶. ثبت امتیاز رسمی مسابقه</h2>
          <div className="field"><label>مسابقه</label><select value={selectedMatch} onChange={e=>{setSelectedMatch(e.target.value);const m=matches.find(x=>x.id===e.target.value);setScoreSets(Array.from({length:3},()=>({home:0,away:0})));}}><option value="">انتخاب مسابقه</option>{matches.filter(m=>m.result_status!=="approved").map(m=><option key={m.id} value={m.id}>{teamNameOf(m.home_team_id)} — {teamNameOf(m.away_team_id)} · {new Date(m.scheduled_at).toLocaleDateString("fa-IR")}</option>)}</select></div>
          {chosenMatch && <form className="grid" onSubmit={sendScore}>
            {scoreSets.map((s,i)=><div className="form-grid" key={i}>
              <div className="field"><label>ست {i+1} — {teamNameOf(chosenMatch.home_team_id)}</label><input type="number" min="0" max="99" required value={s.home} onChange={e=>setScoreSets(cur=>cur.map((x,j)=>j===i?{...x,home:Number(e.target.value)}:x))} /></div>
              <div className="field"><label>ست {i+1} — {teamNameOf(chosenMatch.away_team_id)}</label><input type="number" min="0" max="99" required value={s.away} onChange={e=>setScoreSets(cur=>cur.map((x,j)=>j===i?{...x,away:Number(e.target.value)}:x))} /></div>
            </div>)}
            <div className="topbar-inner" style={{justifyContent:"flex-start"}}><button type="button" className="btn secondary" disabled={scoreSets.length>=chosenMatch.best_of} onClick={()=>setScoreSets(cur=>[...cur,{home:0,away:0}])}>افزودن ست</button><button type="button" className="btn secondary" disabled={scoreSets.length<=3} onClick={()=>setScoreSets(cur=>cur.slice(0,-1))}>حذف ست آخر</button></div>
            {validation && validation.valid === false && <div className="error">{validation.errors.join(" · ")}</div>}
            {validation?.valid && <p role="status">امتیاز معتبر است: {validation.homeSetsWon} بر {validation.awaySetsWon}. پس از ثبت، برای تأیید مدیر ارسال می‌شود.</p>}
            <button className="btn" disabled={busy || !validation?.valid}>ثبت و ارسال نتیجه برای تأیید</button>
          </form>}
          <p className="muted">ثبت رسمی امتیاز فقط برای مالک، مدیر و داور مجاز است. نتیجه تأییدشده قفل می‌شود و اصلاح آن باید از فرایند رسمی انجام شود.</p>
        </section>
      </>}
    </main>
  </>;
}
