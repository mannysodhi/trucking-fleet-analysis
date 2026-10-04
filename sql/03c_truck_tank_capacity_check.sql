-- Tests the "one full tank" explanation for the fuel gap: is the ~320 gallon
-- average purchase per trip (see 03b) just a single tank fill-up?
-- Result: max tank capacity in the fleet is 250 gallons, below the ~320 average
-- purchase per trip. Rules out "single fill-up". Purchases must span multiple
-- fill-ups per trip, or fuel rolling over between trips (see 03b).
SELECT
    round(max(tank_capacity_gallons), 2) as max_tank_capacity,
    round(min(tank_capacity_gallons), 2) as min_tank_capacity,
    round(avg(tank_capacity_gallons), 2) as avg_tank_capacity
from trucks;
