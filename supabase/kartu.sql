-- =====================================================================
-- NOMOR KARTU MEMBER  (jalankan setelah hardening.sql; aman diulang)
-- Nomor dibuat server secara berurutan dan dicatat, sehingga tidak ada
-- dua kartu dengan nomor sama walau dibuat oleh admin yang berbeda.
-- =====================================================================
create table if not exists kartu_member (
  no_member text primary key,
  dibuat_oleh uuid references profiles(id),
  created_at timestamptz not null default now()
);
alter table kartu_member enable row level security;
drop policy if exists k_sel on kartu_member;
create policy k_sel on kartu_member for select to authenticated using (is_staff());

create or replace function buat_nomor_kartu(p_prefix text, p_jumlah int)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  v_raw text := upper(trim(coalesce(p_prefix, 'BM')));
  v_pre text;
  v_year text := to_char(now() at time zone 'Asia/Jakarta', 'YYYY');
  mulai int;
  hasil text[] := '{}';
  v_nomor text;
  k int;
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if v_raw = '' then v_raw := 'BM'; end if;

  -- Bersihkan karakter selain huruf, angka, dan strip
  v_raw := regexp_replace(v_raw, '[^A-Z0-9-]', '', 'g');
  if v_raw = '' then v_raw := 'BM'; end if;

  -- Jika awalan belum ada tahun (misal: 'BM' atau 'GYM'), otomatis jadikan 'BM-2026'
  if v_raw !~ '[0-9]{4}' then
    v_pre := v_raw || '-' || v_year;
  else
    v_pre := v_raw;
  end if;

  if p_jumlah is null or p_jumlah < 1 or p_jumlah > 50 then
    raise exception 'Jumlah kartu 1 sampai 50';
  end if;

  perform pg_advisory_xact_lock(hashtext('kartu_' || v_pre));

  -- Cari nomor urut terakhir untuk awalan ini (misal BM-2026-0001 -> urutan 1)
  select coalesce(max(
    case
      when substring(x.nomor from length(v_pre) + 2) ~ '^[0-9]+$'
      then (substring(x.nomor from length(v_pre) + 2))::bigint
      when substring(x.nomor from length(v_pre) + 1) ~ '^[0-9]+$'
      then (substring(x.nomor from length(v_pre) + 1))::bigint
      else 0
    end
  ), 0) + 1 into mulai
  from (select kk.no_member as nomor from kartu_member kk
        union
        select mm.no_member from members mm) x
  where x.nomor like v_pre || '-%' or x.nomor like v_pre || '%';

  for k in 0 .. p_jumlah - 1 loop
    v_nomor := v_pre || '-' || lpad((mulai + k)::text, 4, '0');
    insert into kartu_member (no_member, dibuat_oleh) values (v_nomor, auth.uid());
    hasil := hasil || v_nomor;
  end loop;

  insert into audit_log (aksi, detail, user_id)
    values ('buat_kartu', hasil[1] || ' s/d ' || hasil[array_length(hasil, 1)], auth.uid());
  return hasil;
end $$;

create or replace function riwayat_kartu(p_limit int default 50)
returns table(nomor text, terdaftar boolean, dibuat timestamptz)
language sql security definer stable set search_path = public as $$
  select k.no_member,
         exists (select 1 from members m where lower(m.no_member) = lower(k.no_member)),
         k.created_at
  from kartu_member k
  where is_staff()
  order by k.created_at desc, k.no_member desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
$$;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('buat_nomor_kartu', 'riwayat_kartu')
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;

notify pgrst, 'reload schema';
