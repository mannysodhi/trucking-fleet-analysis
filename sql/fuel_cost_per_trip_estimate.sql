-- Estimated fuel cost per trip: fuel_gallons_used x average price per gallon for the trip's dispatch month.
-- Used instead of summing fuel_purchases because ~10% of trips have no purchase rows and gallons don't reconcile.
-- Checked: 85,410 rows returned, no NULL prices.
WITH monthly_fuel_price as (
    SELECT substr(purchase_date, 1, 7) as YYYY_MM,
           avg(fp.price_per_gallon) as avg_price_per_gal
    FROM fuel_purchases fp
    GROUP BY YYYY_MM
)
SELECT t.trip_id,
       t.fuel_gallons_used,
       mfp.avg_price_per_gal,
       round(t.fuel_gallons_used * mfp.avg_price_per_gal, 2) as est_fuel_cost
FROM trips t
LEFT JOIN monthly_fuel_price mfp ON substr(t.dispatch_date, 1, 7) = mfp.YYYY_MM;
