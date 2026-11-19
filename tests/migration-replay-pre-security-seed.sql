\set ON_ERROR_STOP on
insert into auth.users(id) values
('10000000-0000-4000-8000-000000000010'),
('10000000-0000-4000-8000-000000000011'),
('10000000-0000-4000-8000-000000000012'),
('10000000-0000-4000-8000-000000000020');
insert into public.sports_tenants(id,name,slug,status) values
('10000000-0000-4000-8000-000000000001','Synthetic Tenant One','synthetic-tenant-one','active'),
('10000000-0000-4000-8000-000000000002','Synthetic Tenant Two','synthetic-tenant-two','active');
insert into public.sports_tenant_memberships(tenant_id,user_id,role,status) values
('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000010','owner','active'),
('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000011','coach','active'),
('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000012','referee','active'),
('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000020','owner','active');
insert into public.sports_members(id,tenant_id,full_name,sport_type,phone,status,birth_date,membership_number,category) values
('10000000-0000-4000-8000-000000000030','10000000-0000-4000-8000-000000000001','Synthetic Athlete One','volleyball','+10000000001','active','2000-01-01','SYN-001','adult'),
('10000000-0000-4000-8000-000000000031','10000000-0000-4000-8000-000000000002','Synthetic Athlete Two','volleyball','+10000000002','active','2001-02-02','SYN-002','adult');
