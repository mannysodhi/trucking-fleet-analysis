-- Is detention actually being billed? Compares average accessorial charges on
-- loads whose delivery ran past the ~2 hour free time vs. loads that didn't.
-- Filtered to Delivery events so there's one row per load (85,410, no fan-out).
-- Result: Billable loads (37,856) average 180 detention minutes vs. 48 for free
-- loads (47,554), nearly 4x longer, but average accessorial charges are the
-- same ($71.45 vs. $71.80). Detention isn't showing up on the bill: the carrier
-- is absorbing it. Unbilled time past free time totals ~37,800 hours at delivery
-- (~49,800 including pickup).
SELECT count(*),
avg(de.detention_minutes) as avg_det_mins,
avg(l.accessorial_charges ) as avg_acc_fee,
Case when de.detention_minutes > 120 then 'Billable' else 'free' end as detention_type
from delivery_events de join loads l on de.load_id = l.load_id 
where de.event_type = 'Delivery'
group by detention_type;
