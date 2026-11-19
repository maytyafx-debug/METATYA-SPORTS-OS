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


## Phase 0 — verified baseline audit (2026-11-19)

- [x] Repository, route, and current PR inventory recorded in `SPORTS_OS_PHASE_0_BASELINE_AUDIT.md`.
- [x] Connected Supabase migration ledger and current sports schema inspected read-only.
- [x] API/RLS role mismatches documented.
- [x] Sensitive `sports_members.phone` and `birth_date` fields identified; a separate private-data table and column-level access proposal added to the pending security migration.
- [x] Member-history hardening and missing foreign-key indexes separated into a follow-on migration.
- [x] Supabase Security and Performance Advisor findings captured.
- [ ] Recover missing historical migration SQL sources and reconcile the local migration chain with the live ledger.
- [ ] Verify the proposed timestamped security migration in an isolated Supabase-compatible database.
- [ ] Add two-tenant/two-user positive and negative RLS integration tests.
- [ ] Validate private-field data-copy counts, grants, access policies, and rollback in isolation.
- [ ] Perform an isolated backup/restore drill.
- [ ] Decide whether the current shared Supabase project is transitional or whether Sports OS requires a separate project/database boundary before public production.

## Confirmed scope boundaries

- No live Supabase schema, policies, rows, Auth settings, or secrets were changed during Phase 0.
- No existing PR was merged.
- The live project is non-empty; treat all existing sports data as production-sensitive.
- Legacy non-sports tables and global Auth settings remain outside this phase and must not be modified as part of Sports OS hardening.
- The new migration is proposed only; do not apply it until the migration-source recovery and isolated test gates pass.
