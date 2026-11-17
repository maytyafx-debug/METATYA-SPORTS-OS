# METATYA Sports OS

هسته عمومی مدیریت باشگاه‌ها و سازمان‌های ورزشی با Next.js و Supabase.

## دامنه فاز اول
- باشگاه‌های عمومی مانند والیبال، شنا و بدنسازی
- چندسازمانی، عضویت و نقش‌ها
- پرونده اعضا، رویدادها و نتایج
- کنترل دسترسی در API و RLS

## راه‌اندازی
1. `.env.example` را به `.env.local` کپی کنید.
2. `NEXT_PUBLIC_SUPABASE_URL` و `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` را تنظیم کنید. کلید قدیمی anon نیز به‌عنوان fallback پشتیبانی می‌شود.
3. فایل `supabase/migrations/006_sports_multitenancy.sql` را در SQL Editor پروژه Supabase اجرا کنید.
4. در فایل `supabase/seed/001_sample_club.sql` ایمیل کاربر Auth موجود را جایگزین placeholder کنید و اسکریپت را یک‌بار اجرا کنید.
5. `npm install` و سپس `npm run dev`.

## امنیت Tenant
مرورگر شناسه سازمان انتخاب‌شده را در هدر `x-tenant-id` می‌فرستد. سرور این مقدار را به‌تنهایی معتبر نمی‌داند: در هر درخواست، کاربر را با `auth.getUser()` احراز می‌کند و عضویت فعال همان کاربر در همان سازمان را از دیتابیس بررسی می‌کند. سپس تمام کوئری‌ها به `tenant_id` تأییدشده محدود می‌شوند. RLS نیز یک لایه دفاعی مستقل است.

هیچ کلید secret یا service-role نباید در متغیر `NEXT_PUBLIC_*` قرار گیرد.
