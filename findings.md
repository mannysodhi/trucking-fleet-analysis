# Findings Log

Running notes on each question investigated. One entry per finding: what I asked,
what I found, why it matters. This is the raw material for the README and for
explaining this project out loud in interviews.

---

## 1. Revenue per mile by route

**Question:** Which routes/lanes generate the most revenue per mile, and does
that change depending on whether fuel surcharge + accessorials are counted?

**Query:** `sql/revenue_per_mile_by_route.sql`

**Method:** Joined `loads`, `trips`, and `routes`. Computed two metrics per route:
- `rev_per_mi` = base revenue / actual miles
- `rev_all_per_mi` = (revenue + fuel surcharge + accessorial charges) / actual miles

Checked the revenue columns for NULLs first (none found) and checked load counts
per route (1,386 to 1,537 each, so no route is too thin to trust).

**Finding:**
- Ranked by `rev_all_per_mi`, short routes (under 500 miles) show up at the top
  most often. Ranked by base `rev_per_mi`, the top of the list shifts mostly to
  longer routes (700+ miles).
- The gap between the two metrics shrinks as distance grows: about $0.90-0.95/mi
  on the 94-mile Philadelphia/New York lane vs. about $0.20-0.36/mi on
  2,400+ mile routes like Columbus to Portland.
- Why: accessorial charges (detention, loading/unloading time) are a flat fee per
  load, not per mile. Dividing a flat fee by a small mileage adds a lot to the
  per-mile rate; dividing it by a long route's mileage adds very little.
- Takeaway: rate per mile alone is not enough to decide which lanes deserve
  capacity. Short lanes look great per mile but long lanes generate far more
  total dollars (e.g. Columbus to Portland is roughly $10.9M all-in).

---

## 2. Backhaul pricing imbalance

**Question:** Is the same lane priced the same in both directions?

**Finding:**
- Backhauls (the return leg of a lane) are not guaranteed to pay the same as the
  outbound leg, because freight demand is not symmetric in both directions.
  When one direction has fewer loads than trucks available, carriers accept a
  lower rate rather than drive back empty (a "deadhead").
- New York to Philadelphia is heavily discounted vs. Philadelphia to New York:
  $1.61/mi vs. $2.79/mi base rate, a 73% gap.
- Portland to Columbus vs. Columbus to Portland: $2.12/mi vs. $2.69/mi, a 21% gap.
  Still discounted, but much less than the short lane.
- The short regional lane shows a bigger imbalance than the long cross-country
  one, possibly because regional city pairs have more one-sided freight flow.
  (Hypothesis, not yet tested.)

---

## 3. Fuel cost per trip: data quality and estimation method

**Question:** After subtracting fuel, which routes are still the most profitable
per mile, and does the ranking change vs. revenue only?

**Data quality issues found:**
- 8,471 of 85,410 trips (about 10%) have no rows in `fuel_purchases`. The gap is
  spread evenly across short, medium, and long trips, so it looks random.
- Where both exist, `fuel_purchases.gallons` (summed per trip) does not match
  `trips.fuel_gallons_used`. Only 286 of 76,939 trips match within 1 gallon.
  Real fill-ups don't line up with individual trips, and the data appears to
  be simulated with the two tables generated independently.

**Decision:** Use Option B: estimated fuel cost = `trips.fuel_gallons_used` x
average `price_per_gallon` for the trip's dispatch month. This covers all 85,410
trips, and ties fuel cost to miles actually driven.

**Price tests:**
- Price varies by year in steps (about $4.20 in 2022, $3.85 in 2023, $3.65 in
  2024) and is flat within each year, so a monthly average is precise enough.
- Price does not vary by location (state averages span only $3.89 to $3.91),
  and the city/state pairs in the data are random, so location was not used.

**Query:** `sql/fuel_cost_per_trip_estimate.sql` (85,410 rows, no NULL prices)

**Sanity check:** on the 76,939 trips with real fuel data, estimated fuel cost
totals $66.5M vs. $95.6M in real purchases. The estimate runs about 30% low
(ratio 0.696). Tested three explanations for why:

1. **Reefer trailers** (`sql/03a_fuel_gap_by_load_type.sql`): refrigerated
   trailers need extra fuel to run the cooling unit, which could explain trips
   showing less "used" fuel than was purchased. Ruled out: Dry Van (0.697) and
   Refrigerated (0.695) came back with essentially the same ratio.
2. **Distance bands** (`sql/03b_fuel_gap_by_distance_band.sql`): average
   purchased gallons stays flat around 316-322 gallons in every distance band,
   while average fuel used scales up with distance as expected. The ratio of
   used-to-purchased climbs from 0.06 on short trips past 1.0 up to 1.57 on the
   longest trips. This fits drivers topping off the tank on a fill-up regardless
   of that specific trip's length, then carrying the extra fuel into later
   trips. Short trips end up "overfueled" on paper and long trips draw down
   fuel bought earlier.
3. **Tank capacity** (`sql/03c_truck_tank_capacity_check.sql`): the ~320 gallon
   average purchase per trip exceeds every truck's tank (max 250, min 150, avg
   200 gallons), so it isn't a single fill-up. Ruled out as a one-tank explanation.

**Conclusion:** the disparity exists because drivers fill the tank at each
fill-up rather than fueling to match one specific trip, and that extra fuel
rolls over into the next load. `fuel_purchases` and `trips.fuel_gallons_used`
don't reconcile at the individual-trip level for this reason, so the estimated
fuel cost used going forward is a reasonable fleet-level approximation, not a
trip-accurate figure.

---

## 4. Profit per mile after fuel, by route

**Question:** After subtracting fuel, which routes are still the most profitable
per mile, and does the ranking change vs. revenue only?

**Query:** `sql/04_profit_after_fuel_by_route.sql`

**Method:** Built revenue per route and estimated fuel cost per route as two
separate CTEs, each rolled up to one row per route, then joined them on
`route_id`. Joining at the same grain avoids fan-out (checked: load counts
match between the two CTEs on every route, and every load has exactly one trip).
Computed:
- `fuel_cost_per_mi` = estimated fuel cost / actual miles
- `profit_after_fuel_per_mi` = (all-in revenue - estimated fuel cost) / actual miles

All-in revenue includes the fuel surcharge, which is what the surcharge is
there to offset, so subtracting fuel from that total is the right comparison.

**Finding:**
- Fuel cost per mile is nearly identical on every route: $0.60-0.61/mi across
  all 58 routes. Fuel price doesn't vary by location (see #3) and gallons used
  scale with miles, so fuel is basically a flat per-mile cost.
- Because of that, subtracting fuel barely moves the ranking. The top 10 is the
  same 10 routes before and after fuel, and no route moves more than 2 spots.
- Philadelphia to New York stays #1 ($3.62 -> $3.01/mi). Las Vegas to Los Angeles
  ($2.53) and Portland to Seattle ($2.41) follow, so the short regional lanes
  still lead, with long lanes like Columbus to Portland ($2.38) right behind.
- The backhaul gap from #2 survives fuel: New York to Philadelphia nets $1.92/mi
  vs. $3.01/mi in the other direction.
- Spread from best to worst route after fuel is $1.91/mi (Philadelphia to
  New York at $3.01 vs. Charlotte to Denver at $1.10).
- Takeaway: in this fleet, fuel doesn't decide which lanes are most profitable.
  Rates and accessorial charges do. If the goal is improving lane margins, the
  lever is pricing, not fuel.

**Caveat:** the fuel estimate runs about 30% low vs. real purchases (see #3), so
real fuel cost is probably closer to ~$0.87/mi and every margin here is
overstated by roughly the same amount. The ranking still holds since the error
is spread evenly, but the absolute profit-per-mile numbers shouldn't be quoted
as exact.

---

## 5. Detention and on-time performance

**Question:** Accessorials drive lane profitability (#4), and detention is the
biggest accessorial. Where does detention happen, and is it actually being billed?

**Queries:** `sql/05a_delivery_events_profile.sql` through `sql/05d_detention_billing_check.sql`

**First look:**
- `delivery_events` has exactly one Pickup and one Delivery event per load
  (85,410 each), so it joins cleanly to `loads` and `trips`.
- Detention is common: average 91.5 minutes, max 239, no NULLs. Only 13% of
  events (22,472) have zero detention.
- Only 55.7% of events are on time (95,095 of 170,820), far below the 90%+ a
  real carrier would aim for.

**Billable detention** (`sql/05b_billable_detention.sql`): shippers and
receivers usually get about 2 hours of free time before detention is billable.
- 36% of all events (61,785) run past the 2-hour free time.
- Delivery is much worse than pickup: 44% of deliveries go billable, averaging
  60 minutes past free time, vs. 28% of pickups at 30 minutes.
- Receivers hold trucks longer than shippers do, so delivery appointments are
  where most detention cost (and driver hours) is lost.
- The billable averages land on exactly 30 and 60 minutes, which suggests the
  detention data was simulated as a roughly even spread (0-179 min at pickup,
  0-239 at delivery). Another sign the dataset is synthetic (see #3).

**On-time by event type** (`sql/05c_on_time_by_event_type.sql`):
- Pickup is on time 66.7% of the time, delivery only 44.6%.
- Delivery is the weak point on both measures: later arrivals and longer
  detention.
- Late and on-time events have the same average detention, and late arrivals
  run about 3 hours late on average. Lateness and detention aren't linked here.
  In real operations a late truck often loses its dock appointment and waits
  longer, so this is another sign the data is simulated.

**Is detention being billed?** (`sql/05d_detention_billing_check.sql`):
- Filtered to delivery events to get one row per load (85,410, no fan-out),
  joined to `loads`, and split loads into past free time (over 120 min) vs. not.
- Loads past free time sat nearly 4x longer (180 min vs. 48 min average), but
  their average accessorial charges are the same: $71.45 vs. $71.80.
- Detention isn't showing up on the bill. The carrier is absorbing the cost of
  trucks and drivers sitting at docks without getting paid for it.
- Rough size: about 37,800 hours past free time at delivery alone (about 49,800
  including pickups). At a typical detention rate of $50-75/hour that's roughly
  $1.9M-$2.8M in delivery detention that could have been billed. (Rate is an
  industry assumption, not from the data.)

**Takeaway:** #4 showed accessorials drive lane profit, and this shows the
biggest accessorial is being left on the table. Delivery is the problem spot:
late more than half the time, and 44% of deliveries run into billable detention
that never gets charged. The fix is operational, not analytical: enforce
detention billing at receivers, starting with the facilities that hold trucks
longest.

**Caveat:** `accessorial_charges` is a single lump per load (lumper, layover,
etc. aren't itemized), so this shows detention isn't driving the charge, not the
exact amount billed for detention.

---
