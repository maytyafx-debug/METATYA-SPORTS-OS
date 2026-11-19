-- 1. اضافه کردن ستون‌های جدید به جدول اعضا
ALTER TABLE public.sports_members 
ADD COLUMN IF NOT EXISTS birth_date DATE,
ADD COLUMN IF NOT EXISTS membership_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS category VARCHAR(100);

-- 2. ساخت جدول تاریخچه (History) برای ثبت تغییرات
CREATE TABLE IF NOT EXISTS public.sports_member_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID NOT NULL REFERENCES public.sports_members(id) ON DELETE CASCADE,
    changed_by UUID REFERENCES auth.users(id),
    change_type VARCHAR(50) NOT NULL, -- 'create', 'update', 'deactivate'
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. فعال کردن امنیت (RLS) برای جدول تاریخچه
ALTER TABLE public.sports_member_history ENABLE ROW LEVEL SECURITY;

-- 4. سیاست‌های دسترسی (فقط ادمین‌ها بتوانند تاریخچه را ببینند و بنویسند)
CREATE POLICY "Admins can view history" ON public.sports_member_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.sports_tenant_memberships m
            WHERE m.user_id = auth.uid() AND m.role = 'admin' AND m.status = 'active'
        )
    );

CREATE POLICY "Admins can insert history" ON public.sports_member_history
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.sports_tenant_memberships m
            WHERE m.user_id = auth.uid() AND m.role = 'admin' AND m.status = 'active'
        )
    );
