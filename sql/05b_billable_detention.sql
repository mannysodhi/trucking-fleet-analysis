-- How much detention is billable? Shippers/receivers usually get ~2 hours (120 min)
-- of free time before detention charges start, so minutes past 120 are billable.
-- Result: 36.2% of all events (61,785 of 170,820) run past free time.
--   Delivery: 44.3% billable, avg 60 min past free time (range 0-239 min)
--   Pickup:   28.0% billable, avg 30 min past free time (range 0-179 min)
-- Receivers hold trucks longer than shippers. Note: the billable averages land
-- on exactly 30.0 / 60.0, the midpoint of each tail, which suggests detention was
-- simulated as roughly uniform (0-179 pickup, 0-239 delivery), another sign the
-- dataset is synthetic (see #3).
SELECT 
de.event_type,
count(*) as num_events,
sum(case when de.detention_minutes > 120 then 1 else 0 end) as billable_events,
round(sum(case when de.detention_minutes > 120 then 1 else 0 end) * 100.0 / count(*), 2) as pct_billable,
round(avg(case when de.detention_minutes > 120 then de.detention_minutes - 120 end), 1) as avg_billable_min
from delivery_events de 
group by de.event_type
union all
SELECT 
'All',
count(*),
sum(case when de.detention_minutes > 120 then 1 else 0 end),
round(sum(case when de.detention_minutes > 120 then 1 else 0 end) * 100.0 / count(*), 2),
round(avg(case when de.detention_minutes > 120 then de.detention_minutes - 120 end), 1)
from delivery_events de;
