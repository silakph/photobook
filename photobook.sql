-- Photobook: run once in Supabase → SQL Editor, in the SAME project as the invites
-- (it reuses public.owners and public.is_owner() from the invite's setup.sql). Safe to run more than once.

-- 1. Books: one row per photobook. Only owners can see or change them.
create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  title text not null default 'Untitled book' check (char_length(title) <= 120),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.books enable row level security;
grant select, insert, update, delete on public.books to authenticated;

drop policy if exists "owners read books" on public.books;
create policy "owners read books" on public.books for select to authenticated using (public.is_owner());
drop policy if exists "owners add books" on public.books;
create policy "owners add books" on public.books for insert to authenticated with check (public.is_owner());
drop policy if exists "owners edit books" on public.books;
create policy "owners edit books" on public.books for update to authenticated using (public.is_owner()) with check (public.is_owner());
drop policy if exists "owners delete books" on public.books;
create policy "owners delete books" on public.books for delete to authenticated using (public.is_owner());

-- 2. Photos: a PRIVATE bucket (not readable by anyone without signing in as an owner),
--    full-size originals up to 50 MB each, plus small previews for the editor.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photobook', 'photobook', false, 52428800, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "owners read photobook photos" on storage.objects;
create policy "owners read photobook photos" on storage.objects
  for select to authenticated using (bucket_id = 'photobook' and public.is_owner());
drop policy if exists "owners add photobook photos" on storage.objects;
create policy "owners add photobook photos" on storage.objects
  for insert to authenticated with check (bucket_id = 'photobook' and public.is_owner());
drop policy if exists "owners change photobook photos" on storage.objects;
create policy "owners change photobook photos" on storage.objects
  for update to authenticated using (bucket_id = 'photobook' and public.is_owner()) with check (bucket_id = 'photobook' and public.is_owner());
drop policy if exists "owners delete photobook photos" on storage.objects;
create policy "owners delete photobook photos" on storage.objects
  for delete to authenticated using (bucket_id = 'photobook' and public.is_owner());
