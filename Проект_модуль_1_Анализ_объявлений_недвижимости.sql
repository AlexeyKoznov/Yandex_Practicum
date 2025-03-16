-- Задача 1. Время активности объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
category_id AS (
	SELECT 
		*,
		last_price/total_area AS price_m2,
		CASE 
			WHEN city = 'Санкт-Петербург'
				THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл'
		END 
			AS type_city,
		CASE 
			WHEN days_exposition BETWEEN 1 AND 30
				THEN 'до месяца'
			WHEN days_exposition BETWEEN 31 AND 90
				THEN 'до 3 месяцев'
			WHEN days_exposition BETWEEN 91 AND 180
				THEN 'до полугода'
			WHEN days_exposition > 180
				THEN 'более полугода'
		END
			AS category_days
	FROM
		real_estate.flats AS f
	FULL JOIN
		real_estate.advertisement AS a USING(id)
	FULL JOIN
		real_estate.city AS c USING(city_id)
	FULL JOIN
		real_estate.type AS t USING(type_id)
	WHERE
		id IN (SELECT * FROM filtered_id) 
		AND TYPE = 'город'
		AND days_exposition IS NOT NULL) 
SELECT 
	type_city,
	category_days,
	COUNT(*) AS count_id,
	ROUND((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY type_city) * 100), 2) AS percent_of_total,
	ROUND((AVG(price_m2)::NUMERIC), 2) AS avg_price_m2,
	ROUND((AVG(total_area)::NUMERIC), 2) AS avg_total_area,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor,
	COUNT(*) FILTER(WHERE floor = 1) AS first_floor_count,
	ROUND((AVG(airports_nearest)::numeric)/1000, 2) as avg_airports_nearest,
	ROUND((AVG(kitchen_area)::NUMERIC), 2) AS avg_kitchen_area,
	ROUND((COUNT(*) FILTER (WHERE open_plan = 1) * 100.0 / COUNT(*)), 2) AS studio_percentage,
	AVG(ceiling_height)::numeric(4,2) AS avg_ceiling_height
FROM
	category_id
GROUP BY
	type_city,
	category_days
ORDER BY 	
	type_city,
    CASE
        WHEN category_days = 'до месяца' THEN 1
        WHEN category_days = 'до 3 месяцев' THEN 2
        WHEN category_days = 'до полугода' THEN 3
        WHEN category_days = 'более полугода' THEN 4
    END;
	
--Задача 2. Сезонность объявлений

-- 2.1 Сезонность публикаций

	WITH date_category AS (
	SELECT 
		id,
        DATE_TRUNC('month', first_day_exposition) AS month_publication,
        last_price / total_area AS price_m2,
        total_area,
        type
    FROM
        real_estate.advertisement AS a
    FULL JOIN
        real_estate.flats AS f USING(id)
    FULL JOIN
    	real_estate.TYPE AS t USING(type_id)
)
SELECT
	EXTRACT(YEAR FROM month_publication) AS year,
	TO_CHAR(month_publication, 'Month') AS MONTH,
	COUNT(*) AS count_publication,
	ROUND((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY EXTRACT(YEAR FROM month_publication)) * 100), 2) AS share_publication,
	ROUND((AVG(price_m2)::NUMERIC), 2) AS avg_price_m2_publication,  
    ROUND((AVG(total_area)::NUMERIC), 2) AS avg_total_area_publication,
    RANK() OVER (PARTITION BY EXTRACT(YEAR FROM month_publication) ORDER BY COUNT(*) DESC) AS rank_publication
FROM
	date_category
WHERE 
	EXTRACT(YEAR FROM month_publication) IN (2015, 2016, 2017, 2018) -- оставил только полные года, где все 12 месяцев
	AND TYPE = 'город'
GROUP BY
	year,
	MONTH;
	
-- 2.2  Сезонность снятия объявлений
	
WITH date_category AS (
	SELECT 
		id,
        DATE_TRUNC('month', first_day_exposition + INTERVAL '1 day' * days_exposition) AS month_removal,
        last_price / total_area AS price_m2,
        total_area,
        type
    FROM
        real_estate.advertisement AS a
    FULL JOIN
        real_estate.flats AS f USING(id)
    FULL JOIN
    	real_estate.TYPE AS t USING(type_id)  
)
SELECT
	EXTRACT(YEAR FROM month_removal) AS year,
	TO_CHAR(month_removal, 'Month') AS month,
	COUNT(*) AS count_removal,
	ROUND((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY EXTRACT(YEAR FROM month_removal)) * 100), 2) AS share_removal,
	ROUND((AVG(price_m2)::NUMERIC), 2) AS avg_price_m2_removal,  
    ROUND((AVG(total_area)::NUMERIC), 2) AS avg_total_area_removal,
    RANK() OVER (PARTITION BY EXTRACT(YEAR FROM month_removal) ORDER BY COUNT(*) DESC) AS rank_removal
FROM
	date_category
WHERE
    month_removal IS NOT NULL
    AND EXTRACT(YEAR FROM month_removal) IN (2017, 2018) -- оставил только полные года, где все 12 месяцев
    AND TYPE = 'город'
GROUP BY
	year,
	month;

-- Задача 3. Анализ рынка недвижимости Ленобласти

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL))
SELECT 
	city,
	COUNT(*) AS count_adv,
	ROUND(COUNT(days_exposition)*1.0 / COUNT(*), 2) AS share_remove_adv,
	ROUND((AVG(last_price/total_area)::NUMERIC), 2) AS avg_price_m2,
	ROUND((AVG(total_area)::NUMERIC), 2) AS avg_total_area,
	ROUND((AVG(days_exposition)::NUMERIC), 2) AS avg_days_exposition
FROM
	real_estate.flats AS f
FULL JOIN
	real_estate.city AS c USING(city_id)
FULL JOIN
	real_estate.advertisement AS a USING(id)
WHERE 
	city <> 'Санкт-Петербург'
	AND id IN (SELECT * FROM filtered_id)
GROUP BY
	city
ORDER BY 
	count_adv DESC
LIMIT 15;