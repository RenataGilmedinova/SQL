--1.������� ��� ������, � ������������ ������� ���������� �������� (��� ����� ��������), � ���� �������� ������� �� ��������� 7 �����.
--������ �� ������ � ������������ ������, ���� ��������

select name,shelf_life
from product
where name ilike '%�������%' and shelf_life <= 7;

--2.��������� ���������� ���������� ������� �� ������� ���� �� ������� ������. ������� ������ �� ������, � ������� ���������� ������� ����� 50.
--������ �� ������ - �����, ���������� �������

select city, count (distinct warehouse_id)
from warehouses
where date_open < current_date () and date_close > current_date ()
group by city
having count (distinct warehouse_id) > 50;

--3.��������� ���������� ������� (SKU), ������� ����������� � ���� 2020 ���� � ������� �� 1 ������, ������ ������� � ������� �������.
--������ �� ������ - �����, ���������� �������, ���������� ������� � ��������� �� 1 �����

select 	w.city as city, 
		count (distinct o.warehouse_id) as number_of_warehouses, 
		sum (o.quantity)/count (distinct o.warehouse_id) as sales_per_1_warehouse
from orders o
left join warehouses w on w.warehouse_id = o.warehouse_id	
where 	extract (year from cast (o.date as date)) = 2020 
		and extract (month from cast (o.date as date)) = 6;

	
--4.��������� ���������� ������� � ���������� �������� � ������� ������� �� 2021 ��� �� �������� � ����� � �� ������� �� �������.
--������ �� ������ � �����/��������, �����, ���������� �������, ���������� ��������

select	w.city,
		extract (month from cast (o.date as date)) as months,
		count(o.order_id) over (partition by o.warehouse_id) as number_of_orders_company,
		count (distinct o.user_id) over (partition by o.warehouse_id) as number_of_users,
		count(o.order_id) over (partition by cast (o.date as date)) as number_of_orders_company,
		count(distinct o.user_id) over (partition by cast (o.date as date)) as number_of_users_company
from orders o
left join warehouses w on w.warehouse_id = o.warehouse_id 
where extract (year from cast (o.date as date)) = 2021);


--5.��������� ������� ����� � ������ �� ������� ������ �� ��������� 14 ����, ��� ���� ������� � ���������� ������� ������������ ������ ��� �������, 
--��� ������� ����� ����, ��� ������� ����� �� ������.
--������ �� ������ � ������������ ������, �����, ������� ����� �� ������, ������� ����� �� ������

with cte1 as (
	select w.name, w.city, avg_w,
	from(
		select 
			warehouse_id,
			avg (paid_amount) as avg_w
		from orders o
		where cast (date as date) > current_date-14
		group by warehouse_id) t
	join warehouse w on w.warehouse_id = o.warehouse_id),
cte2 as (
	select w.city, avg (paid_amount) as avg_c,
	from(
		select 
			warehouse_id,
			avg (paid_amount)
		from orders o
		where cast (date as date) > current_date-14
		group by warehouse_id) t
	join warehouse w on w.warehouse_id = o.warehouse_id),
select 	w.name,
		w.city,
		avg_w, 
		avg_c,
		case (
			when avg_w > avg_c then '������� ����� ����',
			when avg_w < avg_c then '������� ����� ����'
		end)
from cte1
join cte2 on cte2.w.city = cte1.w.city
where case = '������� ����� ����'
order by 1 desc;

--6.���������� % ������ (�� ����� ������, �������� ��� ������) 
--� ���� ������ � ����� ����� ������ �� �������� � ����� �� ��������� 4 ������ �� ������ ������ ������� 2 ������.
--������ �� ������ � ������ ������� 1 ������, ������ ������� 2 ������, % ������ �� ������, ���� ������

with cte1 as (
	select warehouse_id, product_id, sum (paid_amount) as sales
	from order_line ol
	where date::date > (current_date - interval '4 week')
	group by warehouse_id),
cte2 as (
	select warehouse_id, product_id, sum (amount) as loss
	from lost
	where date::date > (current_date - interval '4 week')
	group by warehouse_id, product_id),
cte3 as (
	select product_id, group1, group2
	from product),
cte4 as (
	select product_id, sum(amount) over (partition by date::date) as company_loss
	from lost
	where date::date > (current_date - interval '4 week'))
select 	cte3.group1, 
		cte3.group2, 
		cte2.loss/cte1.sales *100 as loss percentage,
		cte2.loss/cte4.company_loss as proportion_of_losses
from cte2
join cte3 on cte3.product_id = cte2.product_id
join cte1 on cte1.warehouse_id = cte2.warehouse_id
join cte4 on cte4.product_id = cte2.product_id;
		
---7.��������� �������� ������� �� ��� 2021 ���� �� ���� ������� � ������. 
--������ �������� 2 �������� - ������� �� ����� ������ �� 1 ����� � ������ ������ ������� 1 ������ � ������� �� ����� ������ �� 1 ����� � ������ ������ ������� 1 ������. 
--� ����� ������� ���-10 ������� �� ������� � �������� � ������ ������.
--������ �� ������ � ������ ������� 1 ������, ������������ ������, ����� ������ �� 1 �����, ������� �� ��������, ����� ������ �� 1 �����, ������� �� �������

with cte1 as (
	select r.*, row_number () over (partition by p.name order by sales_per_warehouse desc) as rating_1
	from(
		select	p.group1,
				p.name,
				sum (ol.paid_amount)/count (distinct ol.warehouse_id) as sales_per_warehouse,
		from order_line ol
		join product p on p.product_id = ol.product_id
		join warehouses w on w.warehouse_id = ol.warehouse_id 
		where	extract (year from cast (ol.date as date)) = 2021
				and extract (month from cast (ol.date as date)) = 5
				and w.city = '������') r
	limit 10),
cte2 as (
	select r.*, row_number () over (partition by p.name order by loss_per_warehouse desc) as rating_2
	from(
		select	p.group1,
				p.name,
				sum (l.amount)/count (distinct l.warehouse_id) as loss_per_warehouse,
		from lost l
		join product p on p.product_id = l.product_id
		join warehouses w on w.warehouse_id = l.warehouse_id 
		where	extract (year from cast (ol.date as date)) = 2021
				and extract (month from cast (ol.date as date)) = 5
				and w.city = '������') r
	limit 10)
select p.group1, p.name,cte1.sales_per_warehouse,cte1.rating_1, cte2.loss_per_warehouse, cte2.rating_2 
from cte1
join cte2 on cte2.group1 = cte1.group1;