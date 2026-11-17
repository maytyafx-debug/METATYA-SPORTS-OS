# METATYA Sports OS

A general-purpose, multi-tenant sports club management foundation built with Next.js and Supabase.

## Scope
- General non-weapon sports clubs (for example volleyball, swimming, and fitness).
- Organization membership and role-based access.
- Members, events, and results.
- Server-side tenant membership validation on every protected API request.

## Setup
1. Copy `.env.example` to `.env.local`.
2. Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (or the legacy anon key).
3. Run the SQL files in `supabase/migrations` in order using the Supabase SQL Editor.
4. Replace the email placeholder in `supabase/seed/001_sample_club.sql` and run it once.
5. Run `npm install`, then `npm run dev`.

The browser sends the selected `x-tenant-id`, but the API never trusts it on its own: each request authenticates the user and verifies an active membership for that exact tenant. RLS provides a second enforcement layer.

Never put a Supabase secret/service-role key in a `NEXT_PUBLIC_*` variable.
