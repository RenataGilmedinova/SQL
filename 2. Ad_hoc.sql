--��� ������� ������� �������� �������, � ������� �� �������� ������ �������, � �� ����
select * from (
	select t.acc_id, t.trn_date, row_number() over (partition by t.acc_id order by t.trn_date::date)
	from transactions t
	join warehouses w on t.whs_id = w.whs_id) y
where row_number = 1

--�������� ������ ��������, ������� ����� ���������� ������� 8 ������ ������ �� �������� �������� ������� home ��� super
--� ����� 4 ������ �� �������� ������� ������� discounter 
--(����� ��, � ������� ���������� ����� ���������� ����������� ����� 8 � 4 ������ ��������������. 
--���������� ����� ���� � ������ ����� � �� ������ ��� �������, �� ��� ������� ������ �����������)


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
