-- Tests whether refrigerated trailers explain the gap between estimated fuel cost
-- (fuel_gallons_used x monthly avg price) and real fuel_purchases totals.
-- Result: Dry Van ratio 0.697 vs Refrigerated 0.695, essentially identical,
-- so reefer fuel does NOT explain the ~30% estimate-vs-actual gap. Hypothesis ruled out.
WITH monthly_fuel_price as (
    SELECT substr(purchase_date, 1, 7) as YYYY_MM,
           avg(fp.price_per_gallon) as avg_price_per_gal
    FROM fuel_purchases fp
    GROUP BY YYYY_MM
),
fuel_cost as (
    select t.trip_id,
           t.load_id,
           t.fuel_gallons_used,
           mfp.avg_price_per_gal,
           round(t.fuel_gallons_used * mfp.avg_price_per_gal, 2) as est_fuel_cost,
           fp2.total_cost as true_fuel_cost
    from trips t
    left join monthly_fuel_price mfp on substr(t.dispatch_date, 1, 7) = mfp.YYYY_MM
    left join (
        select trip_id, SUM(total_cost) as total_cost
        from fuel_purchases
        group by trip_id
    ) fp2 on t.trip_id = fp2.trip_id
)
select
    l.load_type,
    count(*) as n_trips,
    sum(est_fuel_cost) as sum_est_fuel_cost,
    sum(true_fuel_cost) as sum_true_fuel_cost,
    round(sum(est_fuel_cost) / sum(true_fuel_cost), 3) as ratio_fuel_cost_diff
from fuel_cost
join loads l on fuel_cost.load_id = l.load_id
where fuel_cost.true_fuel_cost is not null
group by l.load_type;
