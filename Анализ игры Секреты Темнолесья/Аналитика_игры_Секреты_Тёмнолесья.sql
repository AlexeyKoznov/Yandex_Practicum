/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Кознов Алексей
 * Дата: 03.01.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

SELECT 	
	COUNT(*) AS total_players_count,
	SUM(payer) AS total_payers_count,
	ROUND(AVG(payer), 4) AS share_payers
FROM
	fantasy.users;
	
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
	
SELECT 
    race,
    SUM(payer) AS payers_count_per_race,
    COUNT(*) AS players_count_per_race,
    ROUND(AVG(payer::NUMERIC), 4) AS share_payers
FROM 
    fantasy.users AS u
LEFT JOIN 
    fantasy.race AS r USING(race_id)
GROUP BY 
    race
ORDER BY 
	share_payers DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
	
SELECT 
	COUNT(transaction_id) AS count_transactions,
	SUM(amount) AS sum_transactions,
	MIN(amount) AS min_transactions,
	MAX(amount) AS max_transactions,
	AVG(amount)::numeric(5,2) AS avg_transactions,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana,
	STDDEV(amount)::numeric(6, 2) AS stand_dev
FROM
	fantasy.events
WHERE 
	amount <> 0;


-- 2.2: Аномальные нулевые покупки:
	
SELECT
    COUNT(transaction_id) FILTER (WHERE amount = 0) AS zero_transactions,
    ROUND(COUNT(transaction_id) FILTER (WHERE amount = 0)::NUMERIC / COUNT(*), 5) AS share_zero_transactions
FROM
    fantasy.events;

-- Сколько игроков покупали и какие предметы за 0 р.л.

SELECT
	id,
    game_items,
    COUNT(transaction_id) 
FROM
    fantasy.events AS e
INNER JOIN 
	fantasy.items AS i USING(item_code)
INNER JOIN 
	fantasy.users AS u USING(id)
WHERE 
	amount  = 0
GROUP BY 
	id,
	game_items;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
	
WITH type_of_players AS (
	SELECT
		id,
		CASE 	
			WHEN payer = 1
				THEN 'payers'
			WHEN payer = 0
				THEN 'no_payers'
		END 
			AS type
	FROM
		fantasy.users
),
transaction_info AS (
	SELECT 
		id,
		COUNT(*) AS count_transactions,
		SUM(amount) AS sum_transactions
	FROM
		fantasy.events
	WHERE 
		amount <> 0
	GROUP BY
		id
	)
SELECT
	type,
	COUNT(*) AS count_players,
	ROUND(AVG(count_transactions)::numeric, 2) AS avg_count_transaction,
	ROUND(AVG(sum_transactions)::numeric, 2) AS avg_sum_transaction
FROM 
	type_of_players AS t
INNER JOIN
	transaction_info AS i USING(id)
GROUP BY
	TYPE;

-- Сравнительный анализ активности платящих и неплатящих игроков в разрезе рас:

WITH type_of_players AS (
    SELECT
        id,
        race,
        CASE    
            WHEN payer = 1
                THEN 'payers'
            WHEN payer = 0
                THEN 'no_payers'
        END 
            AS type
    FROM
        fantasy.users AS  u
    INNER JOIN
        fantasy.race r USING(race_id)
),
transaction_info AS (
    SELECT 
        id,
        COUNT(*) AS count_transactions,
        SUM(amount) AS sum_transactions
    FROM
        fantasy.events
    WHERE 
        amount <> 0
    GROUP BY
        id
)
SELECT
    type,
    race,
    COUNT(*) AS count_players,
    ROUND(AVG(count_transactions)::numeric, 2) AS avg_count_transaction,
    ROUND(AVG(sum_transactions)::numeric, 2) AS avg_sum_transaction
FROM 
    type_of_players AS t
INNER JOIN
    transaction_info AS i USING(id)
GROUP BY
    TYPE,
    RACE
ORDER BY
	race;

-- 2.4: Популярные эпические предметы:
	
WITH item_sales AS (
    SELECT
        game_items,
        COUNT(e.transaction_id) AS transaction_count
    FROM
        fantasy.items AS i
    LEFT JOIN
        fantasy.events AS e USING(item_code)
	WHERE 
		amount <> 0
    GROUP BY
        game_items
),
unique_buyers AS (
    SELECT
        game_items,
        COUNT(DISTINCT id) AS unique_buyers
    FROM
        fantasy.users AS u
    INNER JOIN
        fantasy.events AS e USING(id)
    INNER JOIN
        fantasy.items AS i USING(item_code)
    WHERE 
		amount <> 0    
    GROUP BY
        game_items
),
total_unique_buyers AS (
    SELECT 
    	COUNT(DISTINCT id) AS total_unique_buyers
    FROM 
    	fantasy.users AS u
    INNER JOIN 
    	fantasy.events AS e USING(id)
    WHERE 
    	amount <> 0
)
SELECT
    game_items,
    transaction_count,
    ROUND(transaction_count::numeric / SUM(transaction_count) OVER(), 7) AS share_transaction,
    ROUND(unique_buyers::numeric / total_unique_buyers, 7) AS share_players
FROM
    item_sales AS i
JOIN
    unique_buyers AS ub USING(game_items)
CROSS JOIN
    total_unique_buyers
ORDER BY
    transaction_count DESC;
   
-- Предметы, которые ни разу не покупали:
   
SELECT 
	game_items
FROM
	fantasy.items AS i
LEFT JOIN
	fantasy.events e USING(item_code)
WHERE 	
	transaction_id IS NULL;
   
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

WITH total_players AS (
	SELECT
		race,
		COUNT(id) AS total_players
	FROM
		fantasy.users AS u
	INNER JOIN 
		fantasy.race AS r USING(race_id)
	GROUP BY
		race
),
count_buyers_payers AS (
	SELECT 
		race,
		COUNT(DISTINCT id) AS count_buyers,
		COUNT(DISTINCT id) FILTER (WHERE payer = 1) AS count_payers
	FROM 
		fantasy.users AS u 
	INNER JOIN
		fantasy.events AS e USING(id)
	INNER JOIN
		fantasy.race AS r USING(race_id) 
	WHERE 
		transaction_id IS NOT NULL AND amount <> 0
	GROUP BY
		race
),
player_transactions AS (
    SELECT
    	race,
        u.id,
        COUNT(e.transaction_id) AS count_transaction,
        SUM(e.amount) AS sum_amount
    FROM
        fantasy.users as u
    INNER JOIN
        fantasy.events AS e USING(id)
	INNER JOIN
		fantasy.race AS r USING(race_id) 
	WHERE 
		amount <> 0
    GROUP BY
    	race,
        u.id
),
avg_transactions AS (
	SELECT
		race,
	    ROUND(AVG(count_transaction), 2) AS avg_transaction_per_payer,
	    ROUND(AVG(sum_amount)::numeric / AVG(count_transaction), 2) AS avg_cost_per_purchase,
	    ROUND(AVG(sum_amount)::numeric, 2) AS avg_total_spend_per_payer
	FROM
	    player_transactions
	GROUP BY
		race
)
SELECT 
	tp.race,
	total_players,
	count_buyers,
	ROUND(count_buyers::numeric/total_players, 4)AS share_buyers,
	ROUND(count_payers::NUMERIC/count_buyers, 4) AS share_payers_from_buyers,
	avg_transaction_per_payer,
	avg_cost_per_purchase,
	avg_total_spend_per_payer
FROM
    total_players AS tp
INNER JOIN
    count_buyers_payers AS cb USING(race)
INNER JOIN
    avg_transactions AS at USING(race);

-- Задача 2: Частота покупок
    
WITH purchase_intervals AS (
	SELECT 
		id,
		transaction_id,
		date,
		date::DATE - LAG(date) OVER(PARTITION BY id ORDER BY date)::DATE AS day_between_buy
	FROM
		fantasy.events
	WHERE
		amount > 0
),
user_transactions AS ( 	
	SELECT
		id,
		payer,
		count(transaction_id)  AS count_transactions,
		ROUND(AVG(day_between_buy), 2) AS avg_day_between_buy
	FROM
		purchase_intervals AS p
	INNER JOIN
		fantasy.users AS u USING(id) 
	GROUP BY 
		id,
		payer
	HAVING 	
		count(transaction_id) >= 25
	ORDER BY 	
		id
),
ranked_users AS (
	SELECT 	
		*,
		NTILE(3) OVER(ORDER BY avg_day_between_buy DESC) AS user_ranks
	FROM 
		user_transactions
)
SELECT
	CASE 
		WHEN user_ranks = 1 
			THEN 'высокая частота'
		WHEN user_ranks = 2 
			THEN 'умеренная частота'
		WHEN user_ranks = 3 
			THEN 'низкая частота'	
	END AS user_name_ranks,
	COUNT(DISTINCT id) AS count_players,
	SUM(payer) AS count_payers,
	ROUND(SUM(payer)/COUNT(id)::NUMERIC, 2) AS share_payers,  
	ROUND(AVG(count_transactions), 2) AS avg_transactions_per_player,
	ROUND(AVG(avg_day_between_buy), 2) AS avg_day_between_buy
FROM
	ranked_users
GROUP BY
	user_name_ranks
ORDER BY 
	avg_day_between_buy DESC;

