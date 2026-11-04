-- =====================================================================
-- RESET PASSWORD OLEH SUPER ADMIN  (jalankan setelah hardening.sql)
-- Password di Supabase disimpan ter-hash, jadi TIDAK bisa dilihat siapa pun.
-- Yang bisa dilakukan: Super Admin menetapkan password BARU untuk akun lain.
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;

create or replace function reset_staff_password(p_id uuid, p_password text)
returns void language plpgsql security definer
set search_path = public, auth, extensions as $$
declare v_email text;
begin
  if not is_super() then raise exception 'Hanya Super Admin'; end if;
  if length(coalesce(p_password, '')) < 6 then raise exception 'Password minimal 6 karakter'; end if;
  if p_id = auth.uid() then raise exception 'Untuk akun sendiri pakai menu Ganti password'; end if;
  select email into v_email from profiles where id = p_id;
  if v_email is null then raise exception 'Akun tidak ditemukan'; end if;

  update auth.users
    set encrypted_password = crypt(p_password, gen_salt('bf', 10)), updated_at = now()
    where id = p_id;

  -- paksa login ulang di semua perangkat akun tersebut
  begin
    delete from auth.sessions where user_id = p_id;
  exception when undefined_table then null;
  end;

  insert into audit_log (aksi, detail, user_id) values ('reset_password', v_email, auth.uid());
end $$;

revoke all on function reset_staff_password(uuid, text) from public, anon;
grant execute on function reset_staff_password(uuid, text) to authenticated;
