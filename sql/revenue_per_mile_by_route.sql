-- Revenue per mile by route: base rate (revenue) vs all-in (revenue + fuel surcharge + accessorials)
-- Checked loads.revenue/fuel_surcharge/accessorial_charges for NULLs first (none found) before summing.
SELECT
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
ORDER BY rev_all_per_mi DESC;
