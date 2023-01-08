--ƒл€ каждого клиента выведете магазин, в котором он совершил первую покупку, и ее дату
select * from (
	select t.acc_id, t.trn_date, row_number() over (partition by t.acc_id order by t.trn_date::date)
	from transactions t
	join warehouses w on t.whs_id = w.whs_id) y
where row_number = 1

--¬ыведите список клиентов, которые после совершени€ покупки 8 недель подр€д не посещали магазины формата home или super
--а также 4 недели не помещали магазин формата discounter 
--(Ќужны те, у которых промежуток между ближайшими помещени€ми более 8 и 4 недель соответственно. 
--ѕромежутки могут быть в разное врем€ и от разных дат покупки, но оба услови€ должны выполн€тьс€)


with 
cte1 as (
	select acc_id, whs_id, date_part('week', trn_date), 
	date_part('week',lead(trn_date) over (partition by acc_id order by trn_date)),
	date_part('week', trn_date)-date_part('week',lead(trn_date) over (partition by acc_id order by trn_date)) as diff
	from transactions),
cte2 as (select frmt_name, whs_id
	from warehouses 
	where frmt_name_id="home" or frmt_name_id="super"),
cte3 as (select frmt_name, whs_id
	from warehouses 
	where frmt_name_id= "discounter"),
cte4 as (select * from cte1
	join cte2 on cte2.whs_id = cte1.whs_id
	where diff >=8),
cte5 as (select * from cte1
	join cte3 on cte3.whs_id = cte1.whs_id
	where diff >= 4)
select * from cte5
join cte4 on cte4.acc_id = cte5.whs_id
