create table cust2 as
select *, case
              when jurisdiction = 'Canada' and industry = 'Financial' then 'Domestic Banks'
              when jurisdiction = 'Canada' and industry <> 'Financial' then 'Other Domestic'
              else 'Foreign Cpty'
          end as cpty_type
from customer
;

create table sec2 as
select *, case
              when industry = 'Sovereign' and security_type = 'Bond' then 'Level 1 Asset'
              when industry not in ('Sovereign', 'Financial', 'Insurance') 
                  and issuer_credit_rating like 'A%' 
                  and issuer_credit_rating <> 'A-' then 'Level 2 Asset'
              else 'Level 3 Asset'
          end as asset_class
from sec
;

create table cust_join as
select a.*, b.cpty_type
from col_trans a
left join cust2 b on a.customer_id = b.customer_id
where a.product_type = 'Security'
;

create table sec_join as
select a.*, case
                when b.asset_class is null then c.asset_class
                else b.asset_class
            end as asset_class
from cust_join a left join sec2 b on a.security_id = b.security_id
left join sec2 c on a.security_id =c.security_id_2
;

--Second Method of sec_join
create table sec_join_1 as 
select a.*, coalesce(b.asset_class, c.asset_class) as asset_class
from cust_join a left join sec2 b on a.security_id = b.security_id
left join sec2 c on a.security_id =c.security_id_2
;

--Third Method of sec_join
create table sec_join_2 as 
select a.*, b.asset_class
from cust_join a left join sec2 b on a.security_id = b.security_id
                                  or a.security_id = b.security_id_2
;

--Fourth Method of sec_join (Correlated subquery)
create table sec_join_3 as 
select a.*,
(select b.asset_class from sec2 b
where a.security_id = b.security_id 
or a.security_id = b.security_id_2) as asset_class
from cust_join a
;

create table output as
select cpty_type, 
       case
           when post_direction = 'Deliv to Bank' then 'Collateral Received'
           else 'Collateral Pledged'
       end as direction,
       margin_type,
       sum(case when asset_class = 'Level 1 Asset' then pv_cde else 0 end) as Level_1_Asset,
       sum(case when asset_class = 'Level 2 Asset' then pv_cde else 0 end) as Level_2_Asset,
       sum(case when asset_class = 'Level 3 Asset' then pv_cde else 0 end) as Level_3_Asset
from sec_join
group by cpty_type, direction, margin_type
order by cpty_type, direction, margin_type
;

create table struct as
select a.cpty_type, b.direction, c.margin_type
from (select distinct cpty_type from output) a
cross join (select distinct direction from output) b
cross join (select distinct margin_type from output) c
;

create table col_trans_report as
select a.cpty_type as 'Counterparty Type', a.direction, a.margin_type as 'Collateral Type',
       coalesce(b.Level_1_Asset, 0) as 'Level 1 Asset',
       coalesce(b.Level_2_Asset, 0) as 'Level 2 Asset',
       coalesce(b.Level_3_Asset, 0) as 'Level 3 Asset'
from struct a
left join output b
on a.cpty_type = b.cpty_type and a.direction = b.direction and a.margin_type = b.margin_type
;

