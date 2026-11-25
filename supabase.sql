-- Pokrenuti jednom u SQL Editoru vlastitog Supabase projekta.
create table public.immanis_admins (uid uuid primary key references auth.users(id) on delete cascade);
alter table public.immanis_admins enable row level security;
revoke all on public.immanis_admins from anon, authenticated;
create function public.immanis_is_admin() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.immanis_admins where uid=auth.uid()) $$;
revoke all on function public.immanis_is_admin() from public;
grant execute on function public.immanis_is_admin() to authenticated;
create table public.immanis_upiti (id bigint generated always as identity primary key, created_at timestamptz not null default now(), vrsta text not null, podaci jsonb not null, procitano boolean not null default false);
alter table public.immanis_upiti enable row level security;
revoke all on public.immanis_upiti from anon, authenticated;
grant select, update (procitano), delete on public.immanis_upiti to authenticated;
create policy admin_read on public.immanis_upiti for select to authenticated using (public.immanis_is_admin());
create policy admin_update on public.immanis_upiti for update to authenticated using (public.immanis_is_admin()) with check (public.immanis_is_admin());
create policy admin_delete on public.immanis_upiti for delete to authenticated using (public.immanis_is_admin());
create function public.immanis_submit(p jsonb) returns void language plpgsql security definer set search_path = '' as $$
declare v text := p->>'vrsta'; k text; allowed text[]; required_fields text[];
begin
 if jsonb_typeof(p) is distinct from 'object' or octet_length(p::text)>12000 then raise exception 'Neispravan upit'; end if;
 if coalesce(p->>'website','') <> '' then raise exception 'Neispravan upit'; end if;
 allowed := array['vrsta','ime','email','telefon','poruka','website']; required_fields := array['ime','email'];
 case v when 'knjigovodstvo' then allowed:=allowed||array['tvrtka','zaposleni','racuni','paket']; required_fields:=required_fields||array['tvrtka','zaposleni','racuni','paket']; when 'tehnika' then allowed:=allowed||array['lokacija','usluga']; required_fields:=required_fields||array['lokacija','usluga','poruka']; when 'karijera' then allowed:=allowed||array['odjel','radno_mjesto']; required_fields:=required_fields||array['odjel','poruka']; when 'kontakt' then required_fields:=required_fields||array['poruka']; else raise exception 'Neispravna vrsta'; end case;
 for k in select jsonb_object_keys(p) loop if not(k=any(allowed)) or jsonb_typeof(p->k)<>'string' or length(p->>k)>case when k='poruka' then 4000 else 200 end then raise exception 'Neispravna polja'; end if; end loop;
 foreach k in array required_fields loop if coalesce(btrim(p->>k),'')='' then raise exception 'Nedostaje obavezno polje'; end if; end loop;
 if p->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Neispravan email'; end if;
 if v='knjigovodstvo' and (p->>'zaposleni' !~ '^[0-9]{1,8}$') then raise exception 'Neispravan broj zaposlenika'; end if;
 if v='karijera' and p->>'odjel' not in ('Knjigovodstvo','Grijanje, hlađenje i ventilacija') then raise exception 'Neispravan odjel'; end if;
 insert into public.immanis_upiti(vrsta,podaci) values(v,p-'website'-'vrsta');
end $$;
revoke all on function public.immanis_submit(jsonb) from public;
grant execute on function public.immanis_submit(jsonb) to anon, authenticated;
create table public.immanis_sadrzaj (id integer primary key check(id=1), podaci jsonb not null check(jsonb_typeof(podaci)='object' and octet_length(podaci::text)<500000));
alter table public.immanis_sadrzaj enable row level security;
revoke all on public.immanis_sadrzaj from anon, authenticated;
grant select on public.immanis_sadrzaj to anon, authenticated;
grant insert, update on public.immanis_sadrzaj to authenticated;
create policy public_content on public.immanis_sadrzaj for select using(true);
create policy admin_content_insert on public.immanis_sadrzaj for insert to authenticated with check(public.immanis_is_admin());
create policy admin_content_update on public.immanis_sadrzaj for update to authenticated using(public.immanis_is_admin()) with check(public.immanis_is_admin());
-- Nakon izrade korisnika u Authentication > Users, pokreni zasebno:
-- insert into public.immanis_admins(uid) select id from auth.users where email='info@immanis-usluge.com';
