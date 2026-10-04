-- Tests the tank-size/rollover hypothesis: does purchased fuel scale with trip
-- distance, or does the estimate-vs-actual gap come from something else?
-- Result: avg_purchased_gal is flat (~316-322 gal) across every distance band,
-- while avg_fuel_gal_used scales with distance. ratio_fuel_used climbs from
-- 0.058 (short trips) past 1.0 up to 1.569 (longest trips). Short trips buy far
-- more fuel than they use, long trips use more than was purchased specifically
-- for them. Consistent with drivers filling up periodically and carrying fuel
-- across trips ("rollover"), not with fuel purchases scaling to a single trip.
with fuel as (
    select
        fp.trip_id,
        sum(fp.gallons) as gal_purchased
    from fuel_purchases fp
    group by fp.trip_id
)
SELECT
    case
        when actual_distance_miles between 0 and 200 then '0-200'
        -- 200 mile bucket to highlight local loads
        when actual_distance_miles between 201 and 500 then '201-500'
        -- 300 mile bucket to highlight regional loads
        when actual_distance_miles between 501 and 1000 then '501-1000'
        when actual_distance_miles between 1001 and 1500 then '1001-1500'
        when actual_distance_miles between 1501 and 2000 then '1501-2000'
        when actual_distance_miles between 2001 and 2500 then '2001-2500'
        when actual_distance_miles between 2501 and 3000 then '2501-3000'
        else '>3000'
    END as dist_band,
    sum(actual_distance_miles) as total_miles,
    count(*) as count_trips,
    round(avg(fuel_gallons_used), 2) as avg_fuel_gal_used,
    round(avg(fuel.gal_purchased), 2) as avg_purchased_gal,
    round(avg(fuel_gallons_used) / avg(fuel.gal_purchased), 2) as ratio_fuel_used
from trips join fuel on trips.trip_id = fuel.trip_id
group by dist_band
ORDER BY MIN(actual_distance_miles) asc;
