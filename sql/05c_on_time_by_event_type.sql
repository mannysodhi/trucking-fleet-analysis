-- On-time rate at pickup vs. delivery.
-- Result: Pickup 66.7% on time, Delivery 44.6% on time. Delivery is the weak
-- point on both on-time and detention (see 05b).
-- Side check: late and on-time events have the same average detention
-- (~106 min delivery, ~76 min pickup), and late arrivals run ~3 hours late on
-- average. Lateness and detention aren't linked in this data. In real life a
-- late truck often loses its dock slot and waits longer, so this is another
-- sign the data is simulated.
SELECT 
de.event_type,
round(avg(de.on_time_flag) * 100, 2) as pct_on_time
from delivery_events de 
group by de.event_type;
