create policy "Owner reads admin audit logs"
on public.admin_audit_logs
for select
to authenticated
using (public.is_zoonl_owner());