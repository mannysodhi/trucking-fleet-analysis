-- Ranks routes by profit per mile after subtracting estimated fuel cost
-- (fuel_gallons_used x monthly avg price, see fuel_cost_per_trip_estimate.sql)
-- from all-in revenue (revenue + fuel surcharge + accessorials).
-- Result: fuel cost per mile is nearly flat across all 58 routes ($0.60-0.61/mi),
-- so subtracting it barely changes the ranking vs. rev_all_per_mi. RTE00015
-- (Philadelphia -> New York) stays #1 at $3.62 -> $3.01/mi. Fuel doesn't decide
-- which lanes are most profitable here; revenue and accessorials do.
-- Note: the fuel estimate runs ~30% low vs. real purchases (see 03a-03c), so
-- absolute margins are overstated, but the ranking holds.
with rev_per_mile_by_route as (SELECT
    r.route_id,
    round(sum(l.revenue), 2) as s_rev,
    round(sum(l.revenue + l.fuel_surcharge + l.accessorial_charges), 2) as s_rev_all,
    SUM(t.actual_distance_miles) as dist,
    round(avg(t.actual_distance_miles), 2) as avg_dist,
    round(sum(l.revenue) / SUM(t.actual_distance_miles), 2) as rev_per_mi,
    round(sum(l.revenue + l.fuel_surcharge + l.accessorial_charges) / SUM(t.actual_distance_miles), 2) as rev_all_per_mi,
    count(*) as num_loads,
    r.origin_city,
    r.origin_state,
    r.destination_city,
    r.destination_state
FROM loads l
JOIN routes r ON l.route_id = r.route_id
JOIN trips t ON l.load_id = t.load_id
GROUP BY r.route_id
),
monthly_fuel_price as (
    SELECT substr(purchase_date, 1, 7) as YYYY_MM,
           avg(fp.price_per_gallon) as avg_price_per_gal
    FROM fuel_purchases fp
    GROUP BY YYYY_MM
),
fuel_metrics as (
SELECT t.trip_id,
	   t.load_id,
       t.fuel_gallons_used,
       mfp.avg_price_per_gal,
       round(t.fuel_gallons_used * mfp.avg_price_per_gal, 2) as est_fuel_cost
FROM trips t
LEFT JOIN monthly_fuel_price mfp ON substr(t.dispatch_date, 1, 7) = mfp.YYYY_MM
),
fuel_by_route as (select route_id,
sum(fm.est_fuel_cost) as sum_est_fuel_cost
from fuel_metrics fm join loads l on fm.load_id = l.load_id 
group by l.route_id)
select fbr.route_id,
rpm.origin_city,
rpm.origin_state,
rpm.destination_city,
rpm.destination_state,
rpm.avg_dist,
rpm.num_loads,
rpm.rev_all_per_mi,
round(fbr.sum_est_fuel_cost / rpm.dist , 2) as fuel_cost_per_mi,
round((rpm.s_rev_all - fbr.sum_est_fuel_cost) / rpm.dist , 2) as profit_after_fuel_per_mi
from rev_per_mile_by_route rpm join fuel_by_route fbr on rpm.route_id = fbr.route_id 
ORDER BY profit_after_fuel_per_mi DESC
