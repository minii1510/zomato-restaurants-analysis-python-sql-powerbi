create database zomato;
use zomato;
select count(*) from zomato_cleaned;
select *from zomato_cleaned;
-- Business Queries

-- 1.Top 3 Restaurants in Each City (by Rating then Votes) 
Select * from (
select name ,city ,location , rate , votes,
row_number()over(partition by city order by rate desc , votes desc) as rn
from zomato_cleaned 
where rate is not null
) t 
where rn <= 3
order by city , rn;

-- 2.Top 5 Restaurants in Each Location(Local Leaders)
select * from(
select city , location , name , rate , votes ,
row_number() over(partition by city , location order by rate desc,votes desc) as rn
from zomato_cleaned
where rate is not null
) t
where rn <= 5
order by city , location ,rn;

-- 3. City Rank by Average Ratings (Benchmarking)
select city , round(avg(rate),2) as avg_rating,
dense_rank() over(partition by city order by sum(votes)desc)as location_rank
from zomato_cleaned
group by city
order by city , location_rank ;

-- 4.location Rank Inside each City ( by Total Votes = demand)
select * from(
select city , location,
sum(votes) as total_votes ,
round(avg(rate),2) as avg_rate ,
dense_rank() over(partition by city order by sum(votes)desc)as location_rank
from zomato_cleaned
group by city , location
) t
where location_rank <= 10 
order by city , location_rank;

-- 5. Top 3 Cuisines in Each City (by restaurant count)
SELECT *FROM
 (
SELECT city,cuisines,COUNT(*) AS restaurants,
DENSE_RANK() OVER(PARTITION BY city ORDER BY COUNT(*) DESC) AS cuisine_rank
FROM zomato_cleaned
GROUP BY city, cuisines
) t
WHERE cuisine_rank <= 3
ORDER BY city, cuisine_rank;

-- 6. Top 10 Overall Restaurants (rating rank)
SELECT city, name, location, rate, votes,
RANK() OVER(ORDER BY rate DESC, votes DESC) AS rating_rank
FROM zomato_cleaned
WHERE rate IS NOT NULL
LIMIT 10;

-- 7. Online Order Adoption Ranking (city level)
SELECT
    city,
    COUNT(*) AS total_restaurants,
    SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END) AS online_yes,
    ROUND(100 * SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END) / COUNT(*),2) AS adoption_pct,
    DENSE_RANK() OVER(ORDER BY 
        100 * SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END) / COUNT(*) DESC
    ) AS adoption_rank
FROM zomato_cleaned
GROUP BY city
ORDER BY adoption_rank;

--  8.Best Restaurant Type per City (by avg rating)
SELECT * FROM (
SELECT city, type, COUNT(*) AS restaurants,
ROUND(AVG(rate),2) AS avg_rating,
DENSE_RANK() OVER(PARTITION BY city ORDER BY AVG(rate) DESC) AS type_rank
FROM zomato_cleaned
WHERE rate IS NOT NULL
GROUP BY city, type
) t
WHERE type_rank <= 3
ORDER BY city, type_rank ;

-- 9.Best Rest Type per City (by demand = votes)
SELECT * FROM (
SELECT city ,rest_type,
SUM(votes) AS total_votes, ROUND(AVG(rate),2) AS avg_rating,
        DENSE_RANK() OVER(PARTITION BY city ORDER BY SUM(votes) DESC) AS demand_rank
FROM zomato_cleaned
GROUP BY city, rest_type
) t
WHERE demand_rank <= 5
ORDER BY city, demand_rank;
-- 10. Restaurants performing ABOVE City Average Rating
WITH city_avg AS (
    SELECT city, round(AVG(rate),2) AS city_avg_rating
    FROM zomato_cleaned
    WHERE rate IS NOT NULL
    GROUP BY city
)
SELECT
    z.city, z.name, z.location, z.rate, z.votes,
    c.city_avg_rating
FROM zomato_cleaned z
JOIN city_avg c ON z.city = c.city
WHERE z.rate > c.city_avg_rating
ORDER BY z.city, z.rate DESC, z.votes DESC;


-- TO.10 Onboarding targets(no Online order but strong performance 
with targets as(
select city ,name , location , rate ,votes, online_order ,
row_number() over (partition by city order by rate desc, votes desc) as rn 
from zomato_cleaned
where online_order = 'no'
and rate >=4.0 and  votes >= 100
) 
select * from targets
where rn<= 10 
order by city , rn ;

-- 11 . Price Segment Ranking Inside City ( avg cost)
 SELECT * FROM (
SELECT city, location, ROUND(AVG(cost),0) AS avg_cost,
DENSE_RANK() OVER(PARTITION BY city ORDER BY AVG(cost) DESC) AS expensive_location_rank
    FROM zomato_cleaned
    WHERE cost IS NOT NULL
    GROUP BY city, location
) t
WHERE expensive_location_rank <= 10
ORDER BY city, expensive_location_rank;

-- 12.  Restaurant pricing anomaly Detection (overpriced vs peers)
with peers as(
select city , name , location ,rate , cost, votes,
round(avg(cost)over(partition by city),0)as avg_cost
from zomato_cleaned
where cost is not null and rate is not null
),
ranked as(
select * ,
row_number() over(partition by city order by (cost - avg_cost) desc)as rn
from peers 
)
select city , name, location ,rate , cost,avg_cost,
(cost - avg_cost)as extra_cost
from ranked
where rn <= 10
order by city , extra_cost desc;

