"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  validateVolleyballMatchScore,
  type VolleyballSetScore,
} from "@/lib/sports/volleyball/scoring";

const EMPTY_SET: VolleyballSetScore = { home: 0, away: 0 };

export default function VolleyballDemoPage() {
  const [sets, setSets] = useState<VolleyballSetScore[]>([
    { ...EMPTY_SET },
    { ...EMPTY_SET },
    { ...EMPTY_SET },
  ]);
  const [checked, setChecked] = useState(false);

  const result = useMemo(
    () => validateVolleyballMatchScore({ sets }),
    [sets],
  );

  function updateSet(index: number, side: "home" | "away", value: string) {
    const score = value === "" ? 0 : Number(value);
    setSets((current) =>
      current.map((set, setIndex) =>
        setIndex === index ? { ...set, [side]: score } : set,
      ),
    );
    setChecked(false);
  }

  function addSet() {
    if (sets.length < 5) {
      setSets((current) => [...current, { ...EMPTY_SET }]);
      setChecked(false);
    }
  }

  function removeSet() {
    if (sets.length > 1) {
      setSets((current) => current.slice(0, -1));
      setChecked(false);
    }
  }

  return (
    <main className="shell grid" style={{ maxWidth: 760 }}>
      <div className="topbar-inner" style={{ color: "var(--fg)" }}>
        <div>
          <div className="brand">METATYA · VOLLEYBALL</div>
          <p className="muted">دموی مستقل اعتبارسنجی نتیجه والیبال</p>
        </div>
        <Link className="btn secondary" href="/">بازگشت به صفحه اصلی</Link>
      </div>

      <section className="panel">
        <h1 className="page-heading">آزمایش نتیجه مسابقه</h1>
        <p className="muted">
          این صفحه فقط برای آزمایش منطق امتیازدهی است. هیچ اطلاعاتی ذخیره یا به
          پایگاه داده ارسال نمی‌شود.
        </p>
        <div className="grid">
          {sets.map((set, index) => (
            <div className="panel" key={index}>
              <strong>ست {index + 1}{index === 4 ? " (تعیین‌کننده)" : ""}</strong>
              <div className="form-grid" style={{ marginTop: 12 }}>
                <label className="field">
                  تیم میزبان
                  <input
                    aria-label={`امتیاز میزبان ست ${index + 1}`}
                    type="number"
                    min="0"
                    step="1"
                    value={set.home}
                    onChange={(event) => updateSet(index, "home", event.target.value)}
                  />
                </label>
                <label className="field">
                  تیم میهمان
                  <input
                    aria-label={`امتیاز میهمان ست ${index + 1}`}
                    type="number"
                    min="0"
                    step="1"
                    value={set.away}
                    onChange={(event) => updateSet(index, "away", event.target.value)}
                  />
                </label>
              </div>
            </div>
          ))}
        </div>
        <div className="topbar-inner" style={{ marginTop: 16, justifyContent: "flex-start" }}>
          <button className="btn secondary" type="button" onClick={removeSet} disabled={sets.length <= 1}>حذف ست آخر</button>
          <button className="btn secondary" type="button" onClick={addSet} disabled={sets.length >= 5}>افزودن ست</button>
          <button className="btn" type="button" onClick={() => setChecked(true)}>اعتبارسنجی نتیجه</button>
        </div>
      </section>

      {checked && (
        <section className="panel" aria-live="polite">
          <h2 className="section-title">نتیجه اعتبارسنجی</h2>
          {result.valid ? (
            <p role="status">
              نتیجه از نظر قالب امتیازدهی معتبر است: {result.homeSetsWon} بر
              { " " } {result.awaySetsWon}.
            </p>
          ) : (
            <div role="alert">
              <p>نتیجه معتبر نیست:</p>
              <ul className="list">
                {result.errors.map((error) => <li key={error}>{error}</li>)}
              </ul>
            </div>
          )}
        </section>
      )}
      <p className="muted">
        توجه: این ابزار صرفاً کنترل اولیه قالب امتیاز است و جایگزین قوانین رسمی
        مسابقه، تصمیم داور یا تأیید نتیجه توسط مرجع برگزارکننده نیست.
      </p>
    </main>
  );
}
