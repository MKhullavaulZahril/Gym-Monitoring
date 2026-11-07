-- =====================================================================
-- HAPUS AKUN PERMANEN OLEH SUPER ADMIN  (aman diulang)
-- Akun yang sudah punya riwayat (input harian, member, membership) TIDAK
-- boleh dihapus agar laporan pendapatan tetap benar; gunakan Nonaktifkan.
-- =====================================================================
create or replace function hapus_staff(p_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  v_email text; v_nama text;
  n_visit int; n_member int; n_ms int;
begin
  if not is_super() then raise exception 'Hanya Super Admin'; end if;
  if p_id = auth.uid() then raise exception 'Tidak bisa menghapus akun sendiri'; end if;

  select email, nama into v_email, v_nama from profiles where id = p_id;
  if not found then raise exception 'Akun tidak ditemukan'; end if;

  select count(*) into n_visit  from daily_visits where admin_id = p_id;
  select count(*) into n_member from members      where admin_id = p_id;
  select count(*) into n_ms     from memberships  where admin_id = p_id;
  if n_visit + n_member + n_ms > 0 then
    raise exception 'Akun % sudah punya riwayat (% input harian, % member, % membership) sehingga tidak bisa dihapus permanen agar laporan tetap benar. Gunakan Nonaktifkan.',
      coalesce(v_nama, v_email), n_visit, n_member, n_ms;
  end if;

  -- riwayat pembuatan nomor kartu tetap ada, hanya penandanya dikosongkan
  if to_regclass('public.kartu_member') is not null then
    execute 'update public.kartu_member set dibuat_oleh = null where dibuat_oleh = $1' using p_id;
  end if;

  delete from auth.users where id = p_id;
  delete from profiles where id = p_id;   -- jaga-jaga bila tidak ikut terhapus

  insert into audit_log (aksi, detail, user_id)
    values ('hapus_akun', coalesce(v_email, p_id::text), auth.uid());
end $$;

revoke all on function hapus_staff(uuid) from public, anon;
grant execute on function hapus_staff(uuid) to authenticated;
notify pgrst, 'reload schema';
