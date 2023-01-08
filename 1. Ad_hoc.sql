--1.Вывести все товары, в наименовании которых содержится «самокат» (без учета регистра), и срок годности которых не превышает 7 суток.
--Данные на выходе – наименование товара, срок годности

select name,shelf_life
from product
where name ilike '%самокат%' and shelf_life <= 7;

--2.Посчитать количество работающих складов на текущую дату по каждому городу. Вывести только те города, у которых количество складов более 50.
--Данные на выходе - город, количество складов

select city, count (distinct warehouse_id)
from warehouses
where date_open < current_date () and date_close > current_date ()
group by city
having count (distinct warehouse_id) > 50;

--3.Посчитать количество позиций (SKU), которые продавались в июне 2020 года в среднем на 1 складе, данные вывести в разрезе городов.
--Данные на выходе - город, количество складов, количество товаров с продажами на 1 склад

select 	w.city as city, 
		count (distinct o.warehouse_id) as number_of_warehouses, 
		sum (o.quantity)/count (distinct o.warehouse_id) as sales_per_1_warehouse
from orders o
left join warehouses w on w.warehouse_id = o.warehouse_id	
where 	extract (year from cast (o.date as date)) = 2020 
		and extract (month from cast (o.date as date)) = 6;

	
--4.Посчитать количество заказов и количество клиентов в разрезе месяцев за 2021 год по компании в целом и по каждому из городов.
--Данные на выходе – город/компания, месяц, количество заказов, количество клиентов

select	w.city,
		extract (month from cast (o.date as date)) as months,
		count(o.order_id) over (partition by o.warehouse_id) as number_of_orders_company,
		count (distinct o.user_id) over (partition by o.warehouse_id) as number_of_users,
		count(o.order_id) over (partition by cast (o.date as date)) as number_of_orders_company,
		count(distinct o.user_id) over (partition by cast (o.date as date)) as number_of_users_company
from orders o
left join warehouses w on w.warehouse_id = o.warehouse_id 
where extract (year from cast (o.date as date)) = 2021);


--5.Посчитать средний заказ в рублях по каждому складу за последние 14 дней, при этом вывести в алфавитном порядке наименования только тех складов, 
--где средний заказ выше, чем средний заказ по городу.
--Данные на выходе – наименование склада, город, средний заказ по складу, средний заказ по городу

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
			when avg_w > avg_c then 'средний заказ выше',
			when avg_w < avg_c then 'средний заказ ниже'
		end)
from cte1
join cte2 on cte2.w.city = cte1.w.city
where case = 'средний заказ выше'
order by 1 desc;

--6.Рассчитать % потерь (от суммы продаж, учитывая все статьи) 
--и долю потерь в общей сумме потерь по компании в целом за последние 4 недели по каждой группе товаров 2 уровня.
--Данные на выходе – группа товаров 1 уровня, группа товаров 2 уровня, % потерь от продаж, доля потерь

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
		
---7.Построить рейтинги товаров за май 2021 года по всем складам в Москве. 
--Строим отдельно 2 рейтинга - рейтинг по сумме продаж на 1 склад в рамках группы товаров 1 уровня и рейтинг по сумме потерь на 1 склад в рамках группы товаров 1 уровня. 
--В итоге выводим топ-10 товаров по потерям и продажам в каждой группе.
--Данные на выходе – группа товаров 1 уровня, наименование товара, сумма продаж на 1 склад, рейтинг по продажам, сумма потерь на 1 склад, рейтинг по потерям

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
				and w.city = 'Москва') r
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
				and w.city = 'Москва') r
	limit 10)
select p.group1, p.name,cte1.sales_per_warehouse,cte1.rating_1, cte2.loss_per_warehouse, cte2.rating_2 
from cte1
join cte2 on cte2.group1 = cte1.group1;