
create index if not exists sports_results_event_tenant_idx
  on public.sports_results(event_id, tenant_id);
create index if not exists sports_results_member_tenant_idx
  on public.sports_results(member_id, tenant_id);
create index if not exists sports_tenants_created_by_idx
  on public.sports_tenants(created_by);

