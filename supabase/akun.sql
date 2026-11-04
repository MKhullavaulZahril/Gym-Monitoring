-- =====================================================================
-- KELOLA AKUN OLEH SUPER ADMIN  (jalankan setelah fix_roles.sql; aman diulang)
-- Menggantikan reset_password.sql. Tidak lagi bergantung pada pengaturan
-- Sign Up / Confirm email di Supabase, jadi tombol Tambah akun pasti bisa dipakai.
-- Catatan: password disimpan ter-hash, tidak bisa dilihat; yang bisa dilakukan
-- adalah membuat password BARU.
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;

-- Daftar akun (email diambil dari Auth sehingga tidak pernah kosong)
create or replace function daftar_staff()
returns table(id uuid, nama text, email text, role text, aktif boolean)
language sql security definer stable set search_path = public, auth as $$
  select p.id, p.nama, coalesce(p.email, lower(u.email)), p.role, p.aktif
  from profiles p left join auth.users u on u.id = p.id
  where is_super()
  order by p.role desc, p.nama
$$;

-- Buat akun login baru (atau pasang role pada email yang sudah punya akun)
create or replace function buat_akun_staff(p_email text, p_password text, p_nama text, p_role text)
returns boolean language plpgsql security definer
set search_path = public, auth, extensions as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  uid uuid;
  baru boolean := false;
begin
  if not is_super() then raise exception 'Hanya Super Admin'; end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Format email tidak valid'; end if;
  if trim(coalesce(p_nama, '')) = '' then raise exception 'Nama wajib diisi'; end if;
  if p_role not in ('admin', 'super_admin') then raise exception 'Role tidak valid'; end if;

  select id into uid from auth.users where lower(email) = v_email;
  if uid is null then
    if length(coalesce(p_password, '')) < 6 then raise exception 'Password minimal 6 karakter'; end if;
    uid := gen_random_uuid();
    baru := true;
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', v_email,
      crypt(p_password, gen_salt('bf', 10)), now(),
      '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid,
      jsonb_build_object('sub', uid::text, 'email', v_email, 'email_verified', true),
      'email', uid::text, now(), now(), now()
    );
  elsif uid = auth.uid() and p_role <> 'super_admin' then
    raise exception 'Tidak bisa menurunkan role akun sendiri';
  end if;

  insert into profiles (id, email, nama, role, aktif)
    values (uid, v_email, trim(p_nama), p_role, true)
  on conflict (id) do update
    set email = excluded.email, nama = excluded.nama, role = excluded.role, aktif = true;

  insert into audit_log (aksi, detail, user_id)
    values (case when baru then 'buat_akun' else 'set_role' end, v_email || ' -> ' || p_role, auth.uid());
  return baru;
end $$;

-- Password baru untuk akun lain
create or replace function reset_staff_password(p_id uuid, p_password text)
returns void language plpgsql security definer
set search_path = public, auth, extensions as $$
declare v_email text;
begin
  if not is_super() then raise exception 'Hanya Super Admin'; end if;
  if length(coalesce(p_password, '')) < 6 then raise exception 'Password minimal 6 karakter'; end if;
  if p_id = auth.uid() then raise exception 'Untuk akun sendiri pakai Ganti password'; end if;
  if not exists (select 1 from profiles where id = p_id) then raise exception 'Akun tidak ditemukan'; end if;
  select email into v_email from auth.users where id = p_id;

  update auth.users
    set encrypted_password = crypt(p_password, gen_salt('bf', 10)), updated_at = now()
    where id = p_id;

  begin
    delete from auth.sessions where user_id = p_id;   -- paksa login ulang
  exception when undefined_table then null;
  end;

  insert into audit_log (aksi, detail, user_id) values ('reset_password', coalesce(v_email, p_id::text), auth.uid());
end $$;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('daftar_staff', 'buat_akun_staff', 'reset_staff_password')
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;
