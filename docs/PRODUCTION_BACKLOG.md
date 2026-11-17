# Production Backlog — METATYA Sports OS

این موارد عمداً در فاز MVP / تست تغییر داده نمی‌شوند و باید پیش از Production بررسی و تعیین تکلیف شوند.

## Deferred: Supabase legacy project

- [ ] بررسی هشدارهای Security Advisor مربوط به جدول‌ها و سیاست‌های قدیمی خارج از پیشوند `sports_`؛ در فاز MVP دست‌نخورده بمانند.
- [ ] بررسی تنظیمات Auth مربوط به محافظت در برابر رمزهای افشاشده و تصمیم‌گیری درباره فعال‌سازی آن پیش از Production.
- [ ] اجرای ممیزی جامع Security / Performance Advisor پس از تکمیل هسته ورزشی و پیش از انتشار Production.

## Production readiness — Sports OS

- [ ] تکمیل نقش‌ها و مجوزهای CRUD بر اساس ماتریس دسترسی نهایی.
- [ ] افزودن audit log و تاریخچه تغییرات برای عملیات حساس.
- [ ] بازبینی سیاست‌های RLS برای همه جداول جدید `sports_*` پس از هر Migration.
- [ ] آزمون جداسازی Tenant با حداقل دو کاربر و دو سازمان مستقل.
- [ ] طراحی و آزمون پشتیبان‌گیری و بازیابی انتخابی.
- [ ] افزودن تست‌های یکپارچه API و آزمون‌های منفی دسترسی.
- [ ] تثبیت lockfile و اجرای ممیزی وابستگی‌ها در CI.
- [ ] اجرای آزمون build و استقرار آزمایشی پیش از Production.

## MVP scope guard

در فاز MVP فقط جداول و قابلیت‌های متعلق به `sports_*` موضوع تغییر و ممیزی فعال هستند. هیچ جدول Legacy یا تنظیم Auth خارج از محدوده، بدون درخواست و تأیید جداگانه تغییر داده نمی‌شود.


## Netlify staging — 2026-11-17

- [x] شناسایی مخزن واقعی متصل به Netlify: `maytyafx-debug/METATYA-SPORTS-OS`، شاخه `main`.
- [x] آماده‌سازی `netlify.toml` برای Next.js Runtime و Node.js 22.
- [x] اصلاح فیلتر `webpack.watchOptions.ignored` برای حذف ورودی‌های خالی و RegExp ناسازگار با schema Webpack.
- [ ] افزودن کلید عمومی `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` در Netlify با Scopeهای Builds و Functions و بدون علامت Secret.
- [ ] حذف متغیر قدیمی `NEXT_PUBLIC_SUPABASE_ANON_KEY` پس از تأیید متغیر جدید.
- [x] Netlify production-context build برای commit `3e101462f78a8fa1d3868afb926eff19b890ec02` با وضعیت `ready` منتشر شد؛ Deploy ID: `6afc53b1567e5a2f7dfb5682`. سایت همچنان Team SSO-protected است و این انتشار به معنی تأیید Production عمومی نیست.
- [x] GitHub Actions run `44091103349` برای همین commit موفق شد: TypeScript، ESLint، `npm audit --omit=dev` و Next.js production build.
- [ ] افزودن `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` در Netlify با Scopeهای Builds و Functions و بدون علامت Secret؛ مقدار از Supabase Dashboard دریافت شود.
- [ ] حذف `NEXT_PUBLIC_SUPABASE_ANON_KEY` قدیمی که قبلاً به‌عنوان Secret ذخیره شده بود، پس از تأیید کلید Publishable جدید.
- [ ] اجرای smoke test ورود، نشست، داشبورد و APIها پس از ثبت کلید Publishable.
- [ ] آزمون دو کاربر و دو tenant همچنان پیش‌نیاز rollout گسترده‌تر است؛ در بک‌لاگ امنیتی باقی می‌ماند.

این فاز فقط Deploy محدود/آزمایشی را مجاز می‌کند؛ Production عمومی و داده واقعی همچنان مسدود هستند.
