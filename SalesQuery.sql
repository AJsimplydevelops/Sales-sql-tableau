--Inspecting Data
select * from dbo.sales_data


--Checking unique values
select status from dbo.sales_data --nice on to plot
select distinct year_id from dbo.sales_data
select distinct PRODUCTLINE from dbo.sales_data --PLOT
select distinct COUNTRY from dbo.sales_data --PLOT
select distinct DEALSIZE from dbo.sales_data --PLOT
select distinct TERRITORY from dbo.sales_data --PLOT

select distinct MONTH_ID from dbo.sales_data
where year_id = 2003


--Analysis
--Started by grouping sales by productline
select PRODUCTLINE, sum(sales) Revenue
from dbo.sales_data
group by PRODUCTLINE
order by 2 desc

--Year they made the most sales
select YEAR_ID, sum(sales) Revenue
from dbo.sales_data
group by YEAR_ID
order by 2 desc

--Medium size deals generates most revenue
select DEALSIZE, sum(sales) Revenue
from dbo.sales_data
group by DEALSIZE
order by 2 desc

--What was the best month for sales in a specfic year 
-- & How much was earned in that month ?
select MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER)
from dbo.sales_data
where YEAR_ID = 2004--change year to see the rest
group by MONTH_ID
order by 2 desc

--Our target month is November
--What product do they sell in Novemeber, Classic I should be the case
select MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ORDERNUMBER)
from dbo.sales_data
where YEAR_ID = 2004 and MONTH_ID = 11 --change year to see the rest
group by MONTH_ID, PRODUCTLINE
order by 3 desc


-- Who is the best customer (this could be explained in RFM Analysis)

DROP TABLE IF EXISTS #rfm
;with rfm as
(

	select
		CUSTOMERNAME,
		sum(sales) MonetaryValue,
		avg(sales) AvgMonetaryValue,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from [dbo].[sales_data]) max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data])) Recency 
	from dbo.sales_data
	group by CUSTOMERNAME
),
rfm_calc as
(

select r.*,
	NTILE(4) OVER (order by Recency desc) rfm_recency,
	NTILE(4) OVER (order by Frequency) rfm_frequency,
	NTILE(4) OVER (order by MonetaryValue) rfm_monetary
from rfm r
)

select c.*,
rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar)rfm_cell_string
into #rfm
from rfm_calc c

select CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
	case
		when rfm_cell_string in (111,112, 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customer' --lost the customer
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' --Big Spenders who haven't purchased lately
		when rfm_cell_string in (311, 411, 331) then 'new_customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential_customer'
		when rfm_cell_string in (323, 333, 321, 422, 332, 432) then 'active' --Customers who buy often & recently, but at low prices
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment
from #rfm

--What products are most often sold together? 
select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from dbo.sales_data p
	where ORDERNUMBER in
		(
			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				FROM dbo.sales_data
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))
		
		, 1, 1, '') ProductCodes

from dbo.sales_data s 
ORDER BY 2 desc