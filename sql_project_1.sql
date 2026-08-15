CREATE DATABASE IF NOT EXISTS zomato_analysis;
USE zomato_analysis;

ALTER TABLE zomato ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST;
 
SELECT COUNT(*) AS rows_imported FROM zomato;

-- ---------------------------------------------------------------------
-- STEP 2: Blank strings -> NULL, and trim whitespace, on every text
-- column. Doing this first makes every later cleaning step simpler.
-- ---------------------------------------------------------------------
UPDATE zomato SET address     = NULLIF(TRIM(address), '');
SELECT * FROM zomato;
UPDATE zomato SET name        = NULLIF(TRIM(name), '');
UPDATE zomato SET phone       = NULLIF(TRIM(phone), '');
UPDATE zomato SET location    = NULLIF(TRIM(location), '');
UPDATE zomato SET rest_type   = NULLIF(TRIM(rest_type), '');
UPDATE zomato SET dish_liked  = NULLIF(TRIM(dish_liked), '');
UPDATE zomato SET cuisines    = NULLIF(TRIM(cuisines), '');
UPDATE zomato SET `listed_in(type)` = NULLIF(TRIM(`listed_in(type)`), '');
UPDATE zomato SET `listed_in(city)` = NULLIF(TRIM(`listed_in(city)`), '');
 

ALTER TABLE zomato CHANGE `listed_in(type)` listed_type VARCHAR(50);
ALTER TABLE zomato CHANGE `listed_in(city)` listed_city VARCHAR(100);

 

ALTER TABLE zomato ADD COLUMN rate_num DECIMAL(3,1);
 
UPDATE zomato
SET rate_num = CASE
    WHEN rate IS NULL OR TRIM(rate) IN ('NEW', '-', '') THEN NULL
    ELSE CAST(SUBSTRING_INDEX(REPLACE(rate, ' ', ''), '/', 1) AS DECIMAL(3,1))
END;
 
ALTER TABLE zomato DROP COLUMN rate;
ALTER TABLE zomato CHANGE rate_num rate DECIMAL(3,1);
 

UPDATE zomato SET votes = 0 WHERE votes IS NULL;
 

ALTER TABLE zomato ADD COLUMN approx_cost_num INT UNSIGNED;
 
UPDATE zomato
SET approx_cost_num = CASE
    WHEN `approx_cost(for two people)` IS NULL OR TRIM(`approx_cost(for two people)`) = '' THEN NULL
    ELSE CAST(REPLACE(`approx_cost(for two people)`, ',', '') AS UNSIGNED)
END;
 
ALTER TABLE zomato DROP COLUMN `approx_cost(for two people)`;
ALTER TABLE zomato CHANGE approx_cost_num approx_cost INT UNSIGNED;
 

UPDATE zomato SET online_order = 'Yes' WHERE TRIM(UPPER(online_order)) = 'YES';
UPDATE zomato SET online_order = 'No'  WHERE TRIM(UPPER(online_order)) = 'NO';
UPDATE zomato SET book_table   = 'Yes' WHERE TRIM(UPPER(book_table))   = 'YES';
UPDATE zomato SET book_table   = 'No'  WHERE TRIM(UPPER(book_table))   = 'NO';


SELECT
    COUNT(*)                AS total_rows,
    SUM(rate IS NULL)       AS missing_rate,
    SUM(approx_cost IS NULL) AS missing_cost,
    SUM(location IS NULL)   AS missing_location,
    SUM(rest_type IS NULL)  AS missing_rest_type,
    SUM(cuisines IS NULL)   AS missing_cuisines,
    SUM(dish_liked IS NULL) AS missing_dish_liked
FROM zomato;
 

DROP TABLE IF EXISTS restaurants;
 
CREATE TABLE restaurants AS
SELECT id, name, address, online_order, book_table, rate, votes, location,
       rest_type, dish_liked, cuisines, approx_cost, listed_city, phone
FROM (
    SELECT
        z.*,
        ROW_NUMBER() OVER (PARTITION BY name, address ORDER BY id) AS rn
    FROM zomato z
) t
WHERE rn = 1;
 
SELECT COUNT(*) AS unique_restaurants FROM restaurants;
 


DROP TABLE IF EXISTS restaurant_cuisines;
 
CREATE TABLE restaurant_cuisines AS
WITH RECURSIVE cuisine_split AS (
    SELECT
        id,
        rate,
        votes,
        TRIM(SUBSTRING_INDEX(cuisines, ',', 1))                                 AS cuisine,
        TRIM(SUBSTRING(cuisines, LENGTH(SUBSTRING_INDEX(cuisines, ',', 1)) + 2)) AS remainder
    FROM restaurants
    WHERE cuisines IS NOT NULL
 
    UNION ALL
 
    SELECT
        id,
        rate,
        votes,
        TRIM(SUBSTRING_INDEX(remainder, ',', 1)),
        TRIM(SUBSTRING(remainder, LENGTH(SUBSTRING_INDEX(remainder, ',', 1)) + 2))
    FROM cuisine_split
    WHERE remainder <> ''
)
SELECT id, rate, votes, cuisine
FROM cuisine_split
WHERE cuisine <> '';
 

SELECT COUNT(*) AS cuisine_rows, COUNT(DISTINCT cuisine) AS distinct_cuisines
FROM restaurant_cuisines;
 
 

USE zomato_analysis;
 

SELECT
    (SELECT COUNT(*) FROM zomato)      AS total_listings,
    (SELECT COUNT(*) FROM restaurants) AS unique_restaurants;
 

SELECT
    COUNT(DISTINCT location)    AS distinct_locations,
    COUNT(DISTINCT rest_type)   AS distinct_rest_types,
    COUNT(DISTINCT cuisines)    AS distinct_cuisine_combinations,
    COUNT(DISTINCT listed_city) AS distinct_listed_cities
FROM restaurants;
 

SELECT name, location, votes, rate
FROM restaurants
ORDER BY votes DESC
LIMIT 10;
 

SELECT rest_type, COUNT(*) AS restaurant_count
FROM restaurants
WHERE rest_type IS NOT NULL
GROUP BY rest_type
ORDER BY restaurant_count DESC
LIMIT 10;
 

SELECT location, COUNT(*) AS restaurant_count
FROM restaurants
WHERE location IS NOT NULL
GROUP BY location
ORDER BY restaurant_count DESC
LIMIT 10;
 

SELECT location, ROUND(AVG(rate), 2) AS avg_rating, COUNT(*) AS restaurant_count
FROM restaurants
WHERE rate IS NOT NULL AND location IS NOT NULL
GROUP BY location
HAVING COUNT(*) >= 20
ORDER BY avg_rating DESC
LIMIT 10;
 

SELECT cuisine, COUNT(*) AS restaurant_count
FROM restaurant_cuisines
GROUP BY cuisine
ORDER BY restaurant_count DESC
LIMIT 10;
 

SELECT rest_type, ROUND(AVG(approx_cost), 0) AS avg_cost_for_two, COUNT(*) AS cnt
FROM restaurants
WHERE approx_cost IS NOT NULL AND rest_type IS NOT NULL
GROUP BY rest_type
HAVING COUNT(*) >= 20
ORDER BY avg_cost_for_two DESC
LIMIT 10;
 

SELECT online_order, ROUND(AVG(rate), 2) AS avg_rating, COUNT(*) AS cnt
FROM restaurants
WHERE rate IS NOT NULL
GROUP BY online_order;
 

SELECT book_table, ROUND(AVG(rate), 2) AS avg_rating, COUNT(*) AS cnt
FROM restaurants
WHERE rate IS NOT NULL
GROUP BY book_table;
 

SELECT name, location, rate, votes
FROM restaurants
WHERE rate IS NOT NULL AND votes >= 500
ORDER BY rate DESC, votes DESC
LIMIT 10;
 

SELECT name, location, rate, votes
FROM restaurants
WHERE rate >= 4.5 AND votes >= 1000
ORDER BY votes DESC
LIMIT 10;
 

SELECT name, location, rate, votes,
       ROUND(rate * LN(votes + 1), 2) AS popularity_score
FROM restaurants
WHERE rate IS NOT NULL AND votes > 0
ORDER BY popularity_score DESC
LIMIT 10;
 

SELECT cuisine, ROUND(AVG(rate), 2) AS avg_rating, COUNT(*) AS restaurant_count
FROM restaurant_cuisines
WHERE rate IS NOT NULL
GROUP BY cuisine
HAVING COUNT(*) >= 50
ORDER BY avg_rating DESC
LIMIT 10;
 

SELECT
    location,
    COUNT(*) AS total_restaurants,
    SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END) AS online_order_count,
    ROUND(100.0 * SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_online_order
FROM restaurants
WHERE location IS NOT NULL
GROUP BY location
HAVING COUNT(*) >= 50
ORDER BY pct_online_order DESC
LIMIT 10;
 

SELECT rest_type, ROUND(AVG(approx_cost), 0) AS avg_cost, COUNT(*) AS cnt
FROM restaurants
WHERE approx_cost IS NOT NULL
GROUP BY rest_type
HAVING COUNT(*) >= 5
ORDER BY avg_cost DESC
LIMIT 10;
 

SELECT
    location,
    ROUND(AVG(rate), 2) AS avg_rating,
    ROUND(AVG(approx_cost), 0) AS avg_cost,
    COUNT(*) AS restaurant_count,
    ROUND(AVG(rate) * 10 - AVG(approx_cost) / 200.0, 2) AS value_score
FROM restaurants
WHERE rate IS NOT NULL AND approx_cost IS NOT NULL AND location IS NOT NULL
GROUP BY location
HAVING COUNT(*) >= 20
ORDER BY value_score DESC
LIMIT 10;
 

SELECT ROUND(rate * 2) / 2 AS rating_bucket, COUNT(*) AS cnt
FROM restaurants
WHERE rate IS NOT NULL
GROUP BY rating_bucket
ORDER BY rating_bucket;
 

SELECT
    MIN(approx_cost)          AS min_cost,
    MAX(approx_cost)          AS max_cost,
    ROUND(AVG(approx_cost), 0) AS avg_cost,
    ROUND(AVG(rate), 2)       AS avg_rating
FROM restaurants;
 

SELECT COUNT(*) AS restaurants_without_cuisine
FROM restaurants
WHERE cuisines IS NULL;
 

SELECT listed_type, COUNT(*) AS listing_count
FROM zomato
WHERE listed_type IS NOT NULL
GROUP BY listed_type
ORDER BY listing_count DESC;
 

SELECT ROUND(AVG(cuisine_count), 2) AS avg_cuisines_per_restaurant
FROM (
    SELECT id, COUNT(*) AS cuisine_count
    FROM restaurant_cuisines
    GROUP BY id
) t;
 

SELECT r.name, r.location, r.rate, r.votes, rc.cuisine
FROM restaurants r
JOIN (
    SELECT id, cuisine FROM restaurant_cuisines
    WHERE id IN (SELECT id FROM restaurant_cuisines GROUP BY id HAVING COUNT(*) = 1)
) rc ON rc.id = r.id
WHERE r.rate >= 4.3 AND r.votes >= 50
ORDER BY r.rate DESC, r.votes DESC
LIMIT 10;
 

SELECT
    name,
    location,
    rate,
    votes,
    RANK() OVER (PARTITION BY location ORDER BY rate DESC, votes DESC) AS rank_in_location
FROM restaurants
WHERE rate IS NOT NULL
  AND location = 'Indiranagar'
ORDER BY rank_in_location
LIMIT 10;
 

WITH loc_avg AS (
    SELECT location, AVG(rate) AS avg_rate
    FROM restaurants
    WHERE rate IS NOT NULL
    GROUP BY location
)
SELECT COUNT(*) AS restaurants_above_location_avg
FROM restaurants r
JOIN loc_avg l ON r.location = l.location
WHERE r.rate > l.avg_rate;
 

WITH cuisine_stats AS (
    SELECT
        cuisine,
        COUNT(*) AS restaurant_count,
        AVG(rate) AS avg_rating
    FROM restaurant_cuisines
    WHERE rate IS NOT NULL
    GROUP BY cuisine
    HAVING COUNT(*) >= 30
)
SELECT
    cuisine,
    restaurant_count,
    ROUND(avg_rating, 2) AS avg_rating,
    ROUND((SELECT AVG(rate) FROM restaurant_cuisines WHERE rate IS NOT NULL), 2) AS overall_avg_rating
FROM cuisine_stats
WHERE avg_rating > (SELECT AVG(rate) FROM restaurant_cuisines WHERE rate IS NOT NULL)
ORDER BY avg_rating DESC;
 

SELECT name, location, rate, approx_cost, votes
FROM restaurants
WHERE rate >= 4.3 AND approx_cost <= 400 AND votes >= 100
ORDER BY rate DESC, votes DESC
LIMIT 15;
 

SELECT
    rest_type,
    restaurant_count,
    avg_rating,
    pct_online_order,
    DENSE_RANK() OVER (ORDER BY avg_rating DESC) AS rating_rank
FROM (
    SELECT
        rest_type,
        COUNT(*) AS restaurant_count,
        ROUND(AVG(rate), 2) AS avg_rating,
        ROUND(100.0 * SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_online_order
    FROM restaurants
    WHERE rate IS NOT NULL AND rest_type IS NOT NULL
    GROUP BY rest_type
    HAVING COUNT(*) >= 30
) t
ORDER BY rating_rank
LIMIT 10;