insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('paid-packs', 'paid-packs', false, 20971520, array['text/html','application/pdf','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do update set public = false;
