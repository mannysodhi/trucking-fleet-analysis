-- First look at delivery_events before the detention / on-time analysis.
-- Result:
--   - Exactly 85,410 Pickup + 85,410 Delivery events = one of each per load
--     (matches the 85,410 loads), so the table joins cleanly to loads/trips.
--   - detention_minutes: no NULLs, range 0-239, avg 91.5 min. 22,472 events
--     (13%) have zero detention, so detention is the norm, not the exception.
--   - on_time_flag (0/1): 95,095 of 170,820 events on time = 55.7%. Very low
--     vs. a typical carrier target of 90%+.

-- 1. Events by type
SELECT 
de.event_type ,
count(de.event_type )
from delivery_events de 
group by de.event_type;

-- 2. Detention minutes distribution (count(*) vs count(col) checks for NULLs)
SELECT 
max(de.detention_minutes),
min(de.detention_minutes),
avg(de.detention_minutes ),
count(detention_minutes),
count(*),
sum(case when de.detention_minutes = 0 then 1 else 0 end) as zero_detention
from delivery_events de;

-- 3. On-time share
SELECT 
on_time_flag,
count(on_time_flag),
round(count(*) * 100.0 / sum(count(*)) over (), 2) as pct_of_events
from delivery_events de 
group by on_time_flag;
