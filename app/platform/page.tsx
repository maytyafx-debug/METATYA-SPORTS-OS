"use client";

import Link from "next/link";

const areas = [
  { number: "01", title: "مدیریت ورزش", description: "مدیریت سازمان‌ها، فدراسیون‌ها، باشگاه‌ها، آکادمی‌ها، تیم‌ها و فصل‌های ورزشی.", state: "هسته دامنه‌ای" },
  { number: "02", title: "افراد و توسعه", description: "پرونده ورزشکاران، مربیان و عوامل؛ عضویت، حضور، آموزش و مسیر رشد.", state: "نیازمند تکمیل" },
  { number: "03", title: "مسابقات و عملکرد", description: "رویدادها، تقویم، رقابت‌ها، نتایج و ماژول‌های تخصصی هر رشته.", state: "ماژول‌های مستقل" },
  { number: "04", title: "اقتصاد و امکانات", description: "امکانات، تجهیزات، اسناد و گردش‌کارهای مالی در محدوده مجوز هر سازمان.", state: "در نقشه معماری" },
  { number: "05", title: "هوش و نوآوری", description: "تحلیل عملکرد، شاخص‌ها و ابزارهای تصمیم‌یار با داده‌های مجاز و قابل ردیابی.", state: "در نقشه معماری" },
  { number: "06", title: "زیرساخت و اعتماد", description: "هویت، نقش‌ها، امنیت، حریم خصوصی، ممیزی، یکپارچه‌سازی و تداوم خدمت.", state: "هسته مشترک" },
];

const platformCores = [
  { title: "مدیریت و تنظیمات مرکزی", description: "مدیریت سازمان‌ها و ماژول‌ها، تنظیمات سطح پلتفرم و سازمان، کاربران، نقش‌ها و مجوزها." },
  { title: "گزارش‌گیری مدیریتی", description: "گزارش‌ها و داشبوردهای مدیریتی با محدوده دسترسی سازمانی، منشأ داده و زمان تولید مشخص." },
  { title: "پشتیبان‌گیری و بازیابی", description: "سیاست پشتیبان‌گیری رمزگذاری‌شده، نقاط بازیابی، بازیابی انتخابی و آزمون بازیابی در محیط ایزوله." },
  { title: "سامانه مدیریت ورزشی", description: "هسته عملیاتی مدیریت اعضا، رویدادها و نتایج؛ رشته‌های ورزشی به‌صورت ماژول‌های مستقل به آن متصل می‌شوند." },
];

export default function SportsPlatformPage() {
  return (
    <main className="sport-platform">
      <header className="sp-header">
        <Link href="/platform" className="sp-brand">METATYA <span>SPORT OS</span></Link>
        <span className="sp-kicker">MULTI-CORE SPORTS PLATFORM</span>
      </header>

      <section className="sp-hero">
        <p className="sp-eyebrow">ONE PLATFORM · SHARED CORES · INDEPENDENT SPORT MODULES</p>
        <h1>یک پلتفرم ورزشی،<br /><span>چند هسته هماهنگ.</span></h1>
        <p className="sp-lead">METATYA SPORT OS فقط یک پنل مدیریت باشگاه نیست؛ پلتفرم مادر برای اداره سازمان‌های ورزشی و ارائه هسته‌های مشترک مدیریتی است. هر رشته ورزشی از ماژول تخصصی خود استفاده می‌کند، بدون آنکه تنظیمات، گزارش‌گیری، امنیت یا پشتیبان‌گیری را دوباره بسازد.</p>
        <div className="sp-actions">
          <Link className="sp-button primary" href="/login">ورود به سامانه مدیریت ورزشی</Link>
          <a className="sp-button secondary" href="#cores">مشاهده هسته‌های پلتفرم</a>
        </div>
        <p className="sp-note">این صفحه معرفی معماری و مسیرهای محصول است؛ نمایش هر قابلیت به معنی عملیاتی یا تأیید نهایی بودن آن نیست.</p>
      </section>

      <section className="sp-section" id="cores">
        <div className="sp-section-head"><div><p className="sp-eyebrow">SHARED PLATFORM CORES</p><h2>هسته‌های مشترک پلتفرم</h2></div><p>قابلیت‌های مشترک یک‌بار در سطح پلتفرم ساخته می‌شوند و همه ماژول‌های ورزشی از قراردادهای کنترل‌شده آن‌ها استفاده می‌کنند.</p></div>
        <div className="sp-core-grid">
          {platformCores.map((core, index) => <article className="sp-core-card" key={core.title}><span className="sp-index">CORE {String(index + 1).padStart(2, "0")}</span><h3>{core.title}</h3><p>{core.description}</p></article>)}
        </div>
      </section>

      <section className="sp-section">
        <div className="sp-section-head"><div><p className="sp-eyebrow">SIX PLATFORM AREAS</p><h2>شش حوزه یکپارچه</h2></div><p>تجربه کاربری ساده و منظم می‌ماند؛ معماری داخلی ماژولار است و جزئیات تخصصی هر حوزه در جای درست خود قرار می‌گیرد.</p></div>
        <div className="sp-area-grid">
          {areas.map(area => <article className="sp-area-card" key={area.number}><span className="sp-index">{area.number} / {area.state}</span><h3>{area.title}</h3><p>{area.description}</p></article>)}
        </div>
      </section>

      <section className="sp-principles">
        <p className="sp-eyebrow">PLATFORM GOVERNANCE</p>
        <h2>استقلال رشته‌ها، امنیت سازمان‌ها</h2>
        <div className="sp-principle-grid">
          <p><strong>جداسازی سازمانی:</strong> داده و عملیات هر سازمان فقط در محدوده مجوز معتبر آن قابل دسترسی است.</p>
          <p><strong>ماژولار بودن:</strong> والیبال، فوتبال، تیراندازی و سایر رشته‌ها ماژول‌های مستقل با قواعد تخصصی خود هستند.</p>
          <p><strong>اعتماد و بازیابی:</strong> دسترسی حداقلی، ثبت رویدادهای حساس و بازیابی آزموده‌شده از الزامات پلتفرم‌اند.</p>
        </div>
      </section>

      <footer className="sp-footer"><span>METATYA SPORT OS</span><span>Shared platform · Independent sport modules</span></footer>

      <style jsx>{`
        .sport-platform{--ink:#eaf4f0;--muted:#a8bbb4;--line:rgba(170,220,200,.16);--panel:#10211d;min-height:100vh;background:radial-gradient(ellipse at 80% 0%,#174438 0%,#07110f 48%,#050908 100%);color:var(--ink);padding:0 max(22px,calc((100vw - 1160px)/2));font-family:Vazirmatn,Tahoma,sans-serif}
        .sp-header{height:82px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--line)}
        .sp-brand{font-size:18px;font-weight:800;letter-spacing:.04em;color:var(--ink);text-decoration:none}.sp-brand span{color:#70e5ad}
        .sp-kicker,.sp-eyebrow,.sp-index{font-size:11px;letter-spacing:.1em;color:#78d9a8;font-weight:700}
        .sp-hero{padding:88px 0 76px;max-width:850px}.sp-hero h1{font-size:clamp(38px,7vw,70px);line-height:1.25;margin:20px 0}.sp-hero h1 span{color:#77e4ac}.sp-lead{font-size:17px;line-height:2.1;color:#c2d1cb;max-width:820px}
        .sp-actions{display:flex;gap:12px;flex-wrap:wrap;margin-top:28px}.sp-button{padding:13px 20px;border-radius:10px;text-decoration:none;font-weight:700}.sp-button.primary{background:#72e1a8;color:#062018}.sp-button.secondary{border:1px solid var(--line);color:var(--ink)}.sp-note{font-size:12px;color:var(--muted);margin-top:18px}
        .sp-section{padding:55px 0;border-top:1px solid var(--line)}.sp-section-head{display:flex;justify-content:space-between;gap:28px;align-items:end;margin-bottom:26px}.sp-section-head h2,.sp-principles h2{font-size:30px;margin:10px 0 0}.sp-section-head>p{max-width:460px;color:var(--muted);line-height:1.9;margin:0}
        .sp-core-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}.sp-core-card,.sp-area-card{background:linear-gradient(145deg,rgba(18,43,36,.94),rgba(10,24,20,.94));border:1px solid var(--line);border-radius:16px;padding:22px;min-height:210px}.sp-core-card h3,.sp-area-card h3{font-size:19px;margin:24px 0 10px}.sp-core-card p,.sp-area-card p{color:#b5c8bf;line-height:1.9;font-size:14px;margin:0}
        .sp-area-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.sp-area-card{min-height:190px}
        .sp-principles{padding:56px 0;border-top:1px solid var(--line)}.sp-principle-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px;margin-top:24px}.sp-principle-grid p{color:#b5c8bf;line-height:2;background:rgba(16,33,29,.8);border:1px solid var(--line);padding:18px;border-radius:14px;margin:0}.sp-principle-grid strong{color:#e7f4ee}
        .sp-footer{display:flex;justify-content:space-between;gap:16px;border-top:1px solid var(--line);padding:24px 0;color:var(--muted);font-size:12px}
        @media(max-width:850px){.sp-core-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.sp-area-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.sp-section-head{display:block}.sp-section-head>p{margin-top:14px}}
        @media(max-width:560px){.sport-platform{padding:0 18px}.sp-header{height:68px}.sp-kicker{font-size:9px}.sp-hero{padding:60px 0}.sp-lead{font-size:15px}.sp-core-grid,.sp-area-grid,.sp-principle-grid{grid-template-columns:1fr}.sp-core-card,.sp-area-card{min-height:auto}.sp-section-head h2,.sp-principles h2{font-size:25px}.sp-footer{flex-direction:column}}
      `}</style>
    </main>
  );
}
