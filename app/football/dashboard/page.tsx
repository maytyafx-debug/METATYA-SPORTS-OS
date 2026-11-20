"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";

type Membership = {
  tenant_id: string;
  role: string;
  sports_tenants: { id: string; name: string; slug: string; status: string } | null;
};
type Member = {
  id: string;
  full_name: string;
  sport_type: string | null;
  membership_number: string | null;
  category: string | null;
  status: string;
};
type SportEvent = {
  id: string;
  title: string;
  sport_type: string | null;
  event_date: string;
  location: string | null;
  status: string;
};
type ApiPayload = {
  error?: string;
  members?: Member[];
  events?: SportEvent[];
  member?: Member;
  event?: SportEvent;
};

const FOOTBALL_TENANT_SLUG = "ilam-football";

export default function FootballDashboardPage() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [tenantId, setTenantId] = useState("");
  const [tenantName, setTenantName] = useState("هیئت فوتبال ایلام");
  const [role, setRole] = useState("");
  const [members, setMembers] = useState<Member[]>([]);
  const [matches, setMatches] = useState<SportEvent[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  const [playerName, setPlayerName] = useState("");
  const [membershipNumber, setMembershipNumber] = useState("");
  const [ageCategory, setAgeCategory] = useState("");

  const [homeTeam, setHomeTeam] = useState("");
  const [awayTeam, setAwayTeam] = useState("");
  const [matchDate, setMatchDate] = useState("");
  const [venue, setVenue] = useState("");

  const apiFetch = useCallback(async (path: string, init: RequestInit = {}): Promise<ApiPayload> => {
    if (!tenantId) throw new Error("سازمان فوتبال فعال نیست.");
    const headers = new Headers(init.headers);
    headers.set("x-tenant-id", tenantId);
    if (init.body) headers.set("Content-Type", "application/json");
    const response = await fetch(path, { ...init, headers, cache: "no-store" });
    const payload = (await response.json()) as ApiPayload;
    if (response.status === 401) {
      router.replace("/login");
      throw new Error("نشست شما منقضی شده است.");
    }
    if (!response.ok) throw new Error(payload.error || "درخواست ناموفق بود.");
    return payload;
  }, [tenantId, router]);

  const loadData = useCallback(async () => {
    const [membersPayload, eventsPayload] = await Promise.all([
      apiFetch("/api/sports/members"),
      apiFetch("/api/sports/events"),
    ]);
    setMembers((membersPayload.members ?? []).filter((member) => member.sport_type === "فوتبال"));
    setMatches((eventsPayload.events ?? []).filter((event) => event.sport_type === "فوتبال"));
  }, [apiFetch]);

  useEffect(() => {
    let active = true;
    async function init() {
      try {
        const supabase = createSupabaseBrowserClient();
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
          router.replace("/login");
          return;
        }
        const { data, error } = await supabase
          .from("sports_tenant_memberships")
          .select("tenant_id,role,sports_tenants!inner(id,name,slug,status)")
          .eq("user_id", user.id)
          .eq("status", "active")
          .eq("sports_tenants.status", "active")
          .eq("sports_tenants.slug", FOOTBALL_TENANT_SLUG);
        if (error) throw error;
        const memberships = (data ?? []) as unknown as Membership[];
        if (!memberships.length) {
          if (active) setMessage("حساب شما هنوز به سازمان فعال هیئت فوتبال ایلام متصل نشده است.");
          return;
        }
        if (active) {
          setTenantId(memberships[0].tenant_id);
          setTenantName(memberships[0].sports_tenants?.name ?? "هیئت فوتبال ایلام");
          setRole(memberships[0].role);
        }
      } catch (error) {
        if (active) setMessage(error instanceof Error ? error.message : "خطای دریافت اطلاعات سازمان.");
      } finally {
        if (active) setReady(true);
      }
    }
    void init();
    return () => { active = false; };
  }, [router]);

  useEffect(() => {
    if (!tenantId) return;
    let active = true;
    void loadData().catch((error) => {
      if (active) setMessage(error instanceof Error ? error.message : "دریافت اطلاعات ناموفق بود.");
    });
    return () => { active = false; };
  }, [tenantId, loadData]);

  async function submitPlayer(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      await apiFetch("/api/sports/members", {
        method: "POST",
        body: JSON.stringify({
          full_name: playerName.trim(),
          sport_type: "فوتبال",
          membership_number: membershipNumber.trim() || null,
          category: ageCategory.trim() || null,
        }),
      });
      setPlayerName("");
      setMembershipNumber("");
      setAgeCategory("");
      await loadData();
      setMessage("بازیکن با موفقیت ثبت شد.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ثبت بازیکن ناموفق بود.");
    } finally {
      setBusy(false);
    }
  }

  async function submitMatch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (homeTeam.trim().toLocaleLowerCase() === awayTeam.trim().toLocaleLowerCase()) {
      setMessage("تیم میزبان و میهمان باید متفاوت باشند.");
      return;
    }
    const parsedDate = new Date(matchDate);
    if (Number.isNaN(parsedDate.getTime())) {
      setMessage("تاریخ مسابقه معتبر نیست.");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      await apiFetch("/api/sports/events", {
        method: "POST",
        body: JSON.stringify({
          title: `${homeTeam.trim()} - ${awayTeam.trim()}`,
          sport_type: "فوتبال",
          event_date: parsedDate.toISOString(),
          location: venue.trim() || null,
        }),
      });
      setHomeTeam("");
      setAwayTeam("");
      setMatchDate("");
      setVenue("");
      await loadData();
      setMessage("مسابقه در برنامه رویدادهای فوتبال ثبت شد.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ثبت مسابقه ناموفق بود.");
    } finally {
      setBusy(false);
    }
  }

  async function signOut() {
    await createSupabaseBrowserClient().auth.signOut();
    router.replace("/login");
    router.refresh();
  }

  if (!ready) return <main className="shell"><p>در حال بررسی دسترسی...</p></main>;

  return (
    <>
      <header className="topbar">
        <div className="shell topbar-inner">
          <div>
            <div className="brand">METATYA SPORT OS · FOOTBALL</div>
            <small>پنل اختصاصی هیئت فوتبال ایلام</small>
          </div>
          <div className="topbar-inner">
            <Link className="btn secondary" href="/">هسته مدیریت</Link>
            <button className="btn secondary" onClick={signOut}>خروج</button>
          </div>
        </div>
      </header>
      <main className="shell grid">
        <section>
          <h1 className="page-heading">داشبورد هیئت فوتبال ایلام</h1>
          <p className="muted">مدیریت پایه بازیکنان و برنامه مسابقات</p>
          {tenantId && <p className="muted">سازمان: {tenantName} · سطح دسترسی: {role}</p>}
        </section>

        {!tenantId && message && <section className="panel"><p role="status">{message}</p></section>}

        {tenantId && <>
          <section className="stats">
            <div className="stat"><span className="muted">بازیکنان فوتبال</span><strong>{members.length}</strong></div>
            <div className="stat"><span className="muted">مسابقات برنامه‌ریزی‌شده</span><strong>{matches.length}</strong></div>
          </section>

          <section className="panel">
            <h2 className="section-title">ثبت بازیکن</h2>
            <form className="form-grid" onSubmit={submitPlayer}>
              <div className="field">
                <label htmlFor="football-player-name">نام و نام خانوادگی</label>
                <input id="football-player-name" required minLength={2} maxLength={150} value={playerName} onChange={(e) => setPlayerName(e.target.value)} />
              </div>
              <div className="field">
                <label htmlFor="football-membership-number">شماره عضویت (اختیاری)</label>
                <input id="football-membership-number" maxLength={50} value={membershipNumber} onChange={(e) => setMembershipNumber(e.target.value)} />
              </div>
              <div className="field">
                <label htmlFor="football-age-category">رده سنی / دسته</label>
                <input id="football-age-category" maxLength={100} placeholder="مثلاً نوجوانان" value={ageCategory} onChange={(e) => setAgeCategory(e.target.value)} />
              </div>
              <div className="field full"><button className="btn" disabled={busy}>ثبت بازیکن</button></div>
            </form>
          </section>

          <section className="panel">
            <h2 className="section-title">ثبت مسابقه</h2>
            <form className="form-grid" onSubmit={submitMatch}>
              <div className="field">
                <label htmlFor="football-home-team">تیم میزبان</label>
                <input id="football-home-team" required minLength={2} maxLength={90} value={homeTeam} onChange={(e) => setHomeTeam(e.target.value)} />
              </div>
              <div className="field">
                <label htmlFor="football-away-team">تیم میهمان</label>
                <input id="football-away-team" required minLength={2} maxLength={90} value={awayTeam} onChange={(e) => setAwayTeam(e.target.value)} />
              </div>
              <div className="field">
                <label htmlFor="football-match-date">تاریخ و ساعت</label>
                <input id="football-match-date" type="datetime-local" required value={matchDate} onChange={(e) => setMatchDate(e.target.value)} />
              </div>
              <div className="field">
                <label htmlFor="football-match-venue">ورزشگاه / محل برگزاری</label>
                <input id="football-match-venue" maxLength={200} value={venue} onChange={(e) => setVenue(e.target.value)} />
              </div>
              <div className="field full"><button className="btn" disabled={busy}>ثبت مسابقه</button></div>
            </form>
            <p className="muted">در نسخه پایه، مسابقه در هسته مشترک رویدادها با عنوان «میزبان - میهمان» ذخیره می‌شود.</p>
          </section>

          <section className="panel">
            <h2 className="section-title">فهرست بازیکنان</h2>
            {members.length === 0 ? <p className="muted">هنوز بازیکنی ثبت نشده است.</p> : (
              <ul className="list">{members.map((member) => (
                <li key={member.id}>
                  <strong>{member.full_name}</strong>
                  <span className="muted"> · {member.category ?? "رده ثبت نشده"} · {member.membership_number ?? "بدون شماره عضویت"}</span>
                </li>
              ))}</ul>
            )}
          </section>

          <section className="panel">
            <h2 className="section-title">برنامه مسابقات</h2>
            {matches.length === 0 ? <p className="muted">هنوز مسابقه‌ای ثبت نشده است.</p> : (
              <ul className="list">{matches.map((match) => (
                <li key={match.id}>
                  <strong>{match.title}</strong>
                  <div className="muted">{new Date(match.event_date).toLocaleString("fa-IR")} · {match.location ?? "محل تعیین نشده"}</div>
                </li>
              ))}</ul>
            )}
          </section>
        </>}

        {tenantId && message && <p className="status" role="status" aria-live="polite">{message}</p>}
      </main>
    </>
  );
}
