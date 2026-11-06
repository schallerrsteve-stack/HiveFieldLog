-- FieldLog cloud sync: run this once in your Supabase project (SQL Editor > New query > Run).
-- Every signed-in user of this Supabase project shares the same FieldLog data,
-- so only create accounts for your own team (and turn off public sign-ups).

create sequence if not exists public.fieldlog_seq;

create table if not exists public.fieldlog_records (
  id          text primary key,                 -- project id or hole id
  kind        text not null,
  project_id  text not null,
  data        jsonb not null,                   -- the full project info or hole record
  updated_at  timestamptz not null,             -- when the record was last edited on a device
  deleted     boolean not null default false,   -- deleted holes stay as tombstones so every device removes them
  updated_by  text,                             -- email of the user who sent this version
  seq         bigint not null default nextval('public.fieldlog_seq')  -- change counter devices pull from
);
-- record kinds: projects, holes, and the company template ('config')
alter table public.fieldlog_records drop constraint if exists fieldlog_records_kind_check;
alter table public.fieldlog_records add constraint fieldlog_records_kind_check check (kind in ('project', 'hole', 'config'));
create index if not exists fieldlog_records_seq_idx on public.fieldlog_records (seq);

-- people allowed to publish the company template (pick lists, log layout, field rules, graphics).
-- Add your admins here, e.g.:  insert into public.fieldlog_admins (email) values ('you@company.ca') on conflict do nothing;
create table if not exists public.fieldlog_admins (email text primary key);
alter table public.fieldlog_admins enable row level security;  -- no policies: only readable through the functions below

create or replace function public.fieldlog_am_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.fieldlog_admins a where lower(a.email) = lower(coalesce(auth.jwt()->>'email', '')))
$$;
revoke all on function public.fieldlog_am_admin() from public, anon;
grant execute on function public.fieldlog_am_admin() to authenticated;
create index if not exists fieldlog_records_project_idx on public.fieldlog_records (project_id);

alter table public.fieldlog_records enable row level security;

drop policy if exists "fieldlog team can read" on public.fieldlog_records;
create policy "fieldlog team can read" on public.fieldlog_records
  for select to authenticated using (true);
-- No insert/update/delete policies: all writes go through fieldlog_push below.

-- Upload a batch of records. A record only replaces the stored one when it is newer,
-- and a deletion always wins. Returns how many were accepted, plus the server's copy of
-- any record that was refused, so the sending device can correct itself.
drop function if exists public.fieldlog_push(jsonb);
create or replace function public.fieldlog_push(records jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r jsonb;
  n integer := 0;
  accepted integer;
  refused jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  for r in select * from jsonb_array_elements(records) loop
    if r->>'kind' = 'config' and not public.fieldlog_am_admin() then  -- only admins may change the company template
      refused := refused || coalesce((select jsonb_agg(to_jsonb(t)) from public.fieldlog_records t where t.id = r->>'id'), '[]'::jsonb);
      continue;
    end if;
    insert into public.fieldlog_records as t (id, kind, project_id, data, updated_at, deleted, updated_by)
    values (
      r->>'id', r->>'kind', r->>'project_id', coalesce(r->'data', '{}'::jsonb),
      (r->>'updated_at')::timestamptz, coalesce((r->>'deleted')::boolean, false),
      coalesce(auth.jwt()->>'email', '')
    )
    on conflict (id) do update
      set kind = excluded.kind, project_id = excluded.project_id, data = excluded.data,
          updated_at = excluded.updated_at, deleted = excluded.deleted,
          updated_by = excluded.updated_by, seq = nextval('public.fieldlog_seq')
      where not t.deleted
        and (excluded.deleted or excluded.updated_at > t.updated_at);
    get diagnostics accepted = row_count;
    n := n + accepted;
    if accepted = 0 then
      refused := refused || coalesce((select jsonb_agg(to_jsonb(t)) from public.fieldlog_records t where t.id = r->>'id'), '[]'::jsonb);
    end if;
  end loop;
  return jsonb_build_object('accepted', n, 'refused', refused);
end;
$$;

revoke all on function public.fieldlog_push(jsonb) from public;
revoke all on function public.fieldlog_push(jsonb) from anon;
grant execute on function public.fieldlog_push(jsonb) to authenticated;
grant select on public.fieldlog_records to authenticated;
