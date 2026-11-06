-- FieldLog live layers for QGIS (run once in Supabase: SQL Editor > New query > Run, after supabase.sql).
-- Creates a separate "fieldlog_gis" schema with read-only views, and a login that can only read them.
-- The views are not exposed through the app's API, so the publishable key cannot reach them.

create extension if not exists postgis with schema extensions;
create schema if not exists fieldlog_gis;

-- numbers stored as text in the app ("1.50", "", "50/75") -> numeric or null
create or replace function fieldlog_gis.num(t text) returns double precision
language sql immutable as $$
  select case when t ~ '^\s*-?[0-9]+([.,][0-9]+)?\s*$' then replace(trim(t), ',', '.')::double precision end
$$;

-- one row per hole, point geometry (WGS84), with interpretation values for labelling and contouring
create or replace view fieldlog_gis.holes as
select h.id, h.project_id,
       p.data->>'number' as project_no, p.data->>'name' as project,
       h.data->>'holeId' as hole_id, h.data->>'type' as type, h.data->>'status' as status,
       coalesce(h.data->>'review', 'Draft') as review, h.data->>'logger' as logged_by,
       h.data->>'startDate' as start_date, h.data->>'method' as method,
       fieldlog_gis.num(h.data->>'groundElev') as ground_elev, h.data->>'elevDatum' as elev_datum,
       (h.data->'_geo'->>'epsg')::int as proj_epsg,
       (h.data->'_geo'->>'x')::double precision as proj_x, (h.data->'_geo'->>'y')::double precision as proj_y,
       h.data->'_geo'->>'source' as location_source,
       (h.data->'_geo'->'summary'->>'depth')::double precision as depth,
       (h.data->'_geo'->'summary'->>'eoh_elev')::double precision as eoh_elev,
       (h.data->'_geo'->'summary'->>'rock_depth')::double precision as rock_depth,
       (h.data->'_geo'->'summary'->>'rock_elev')::double precision as rock_elev,
       (h.data->'_geo'->'summary'->>'rock_deeper_than')::double precision as rock_deeper_than,
       (h.data->'_geo'->'summary'->>'fill_thick')::double precision as fill_thick,
       (h.data->'_geo'->'summary'->>'base_fill_elev')::double precision as base_fill_elev,
       (h.data->'_geo'->'summary'->>'gw_depth')::double precision as gw_depth,
       (h.data->'_geo'->'summary'->>'gw_elev')::double precision as gw_elev,
       h.data->'_geo'->'summary'->>'gw_date' as gw_date,
       (h.data->'_geo'->'summary'->>'max_n')::double precision as max_n,
       (h.data->'_geo'->'summary'->>'refusal_depth')::double precision as refusal_depth,
       (h.data->'_geo'->'summary'->>'screen_top_elev')::double precision as screen_top_elev,
       (h.data->'_geo'->'summary'->>'screen_bot_elev')::double precision as screen_bot_elev,
       h.updated_at, h.updated_by,
       case when h.data->'_geo'->>'lat' is not null
            then extensions.st_setsrid(extensions.st_makepoint((h.data->'_geo'->>'lon')::float8, (h.data->'_geo'->>'lat')::float8), 4326) end::extensions.geometry(Point, 4326) as geom
from public.fieldlog_records h
join public.fieldlog_records p on p.id = h.project_id and p.kind = 'project'
where h.kind = 'hole' and not h.deleted;

-- one row per stratum (at the hole location) with top/bottom depth and elevation and the description printed on the log
create or replace view fieldlog_gis.strata as
select h.id || ':' || s.ord as id, h.project_id, h.project_no, h.hole_id, s.ord::int as seq,
       (s.v->>'top')::float8 as top_depth, (s.v->>'bottom')::float8 as bot_depth,
       round((h.ground_elev - (s.v->>'top')::float8)::numeric, 3)::float8 as top_elev, round((h.ground_elev - (s.v->>'bottom')::float8)::numeric, 3)::float8 as bot_elev,
       s.v->>'uscs' as uscs, s.v->>'group' as unit_group, s.v->>'description' as description, h.geom
from fieldlog_gis.holes h
join public.fieldlog_records r on r.id = h.id
cross join lateral jsonb_array_elements(coalesce(r.data->'_geo'->'strata', '[]'::jsonb)) with ordinality as s(v, ord);

-- water observations
create or replace view fieldlog_gis.water as
select h.id || ':' || w.ord as id, h.project_id, h.project_no, h.hole_id,
       w.v->>'kind' as observation, fieldlog_gis.num(w.v->>'depth') as depth,
       round((h.ground_elev - fieldlog_gis.num(w.v->>'depth'))::numeric, 3)::float8 as elev, w.v->>'date' as date, w.v->>'time' as time, w.v->>'note' as note, h.geom
from fieldlog_gis.holes h
join public.fieldlog_records r on r.id = h.id
cross join lateral jsonb_array_elements(r.data->'water') with ordinality as w(v, ord);

-- samples with SPT N-values (refusals kept as text, e.g. 50/75)
create or replace view fieldlog_gis.samples as
select h.id || ':' || x.ord as id, h.project_id, h.project_no, h.hole_id, x.v->>'sample' as sample, x.v->>'type' as type,
       (x.v->>'top')::float8 as top_depth, (x.v->>'bottom')::float8 as bot_depth,
       round((h.ground_elev - ((x.v->>'top')::float8 + coalesce((x.v->>'bottom')::float8, (x.v->>'top')::float8)) / 2)::numeric, 3)::float8 as mid_elev,
       x.v->>'blows' as blows, (x.v->>'n')::float8 as n_value, x.v->>'refusal' as refusal,
       (x.v->>'rec_pct')::float8 as recovery_pct, (x.v->>'rqd')::float8 as rqd, x.v->>'labs' as lab_tests, h.geom
from fieldlog_gis.holes h
join public.fieldlog_records r on r.id = h.id
cross join lateral jsonb_array_elements(coalesce(r.data->'_geo'->'samples', '[]'::jsonb)) with ordinality as x(v, ord);

-- fence diagram section lines, in the order chosen in the app
create or replace view fieldlog_gis.sections as
select p.id as project_id, p.data->>'number' as project_no, coalesce(p.data->'fence'->>'name', 'A-A''') as name,
       extensions.st_makeline(h.geom order by o.ord)::extensions.geometry(LineString, 4326) as geom
from public.fieldlog_records p
cross join lateral jsonb_array_elements_text(p.data->'fence'->'holes') with ordinality as o(hole, ord)
join fieldlog_gis.holes h on h.id = o.hole and h.geom is not null
where p.kind = 'project' and not p.deleted
group by p.id, p.data
having count(*) > 1;

-- the views read the synced table as their owner; make sure row-level security lets the owner through
drop policy if exists "fieldlog gis views" on public.fieldlog_records;
create policy "fieldlog gis views" on public.fieldlog_records for select to postgres using (true);

-- read-only login for QGIS. CHANGE THE PASSWORD before running.
do $$ begin
  create role fieldlog_qgis login password 'change-me-to-a-long-password';
exception when duplicate_object then null; end $$;
revoke all on schema fieldlog_gis from public;
grant usage on schema fieldlog_gis, extensions to fieldlog_qgis;
grant select on all tables in schema fieldlog_gis to fieldlog_qgis;
grant execute on function fieldlog_gis.num(text) to fieldlog_qgis;
revoke all on all tables in schema fieldlog_gis from anon, authenticated;
