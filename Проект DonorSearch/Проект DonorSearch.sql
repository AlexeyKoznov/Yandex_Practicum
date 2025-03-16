-- 1) Определить регионы с наибольшим количеством зарегистрированных доноров
SELECT region,
       COUNT(id) AS donor_count
FROM donorsearch.user_anon_data
GROUP BY region
ORDER BY donor_count DESC
LIMIT 5;


-- 2) Изучить динамику общего количества донаций в месяц за 2022 и 2023 годы. 
SELECT DATE_TRUNC('month', donation_date) AS month,
       COUNT(id) AS donation_count
FROM donorsearch.donation_anon
WHERE donation_date BETWEEN '2022-01-01' AND '2023-12-31'
GROUP BY month
ORDER BY month;


-- 3) Определить наиболее активных доноров в системе, учитывая только данные о зарегистрированных и подтвержденных донациям.
SELECT id,
       confirmed_donations
FROM donorsearch.user_anon_data
ORDER BY confirmed_donations DESC
LIMIT 10;


-- 4) Оценить, как система бонусов влияет на зарегистрированные в системе донации.
WITH donor_activity AS
  (SELECT u.id,
          u.confirmed_donations,
          COALESCE(b.user_bonus_count, 0) AS user_bonus_count
   FROM donorsearch.user_anon_data u
   LEFT JOIN donorsearch.user_anon_bonus b ON u.id = b.user_id)
SELECT CASE
           WHEN user_bonus_count > 0 THEN 'Получили бонусы'
           ELSE 'Не получали бонусы'
       END AS статус_бонусов,
       COUNT(id) AS количество_доноров,
       AVG(confirmed_donations) AS среднее_количество_донаций
FROM donor_activity
GROUP BY статус_бонусов;


-- Задача 5. Исследовать вовлечение новых доноров через социальные сети,
--  учитывая только тех, кто совершил хотя бы одну донацию. Узнать, сколько 
--  по каким каналам пришло доноров, и среднее количество донаций по каждому каналу.
SELECT CASE
           WHEN autho_vk THEN 'ВКонтакте'
           WHEN autho_ok THEN 'Одноклассники'
           WHEN autho_tg THEN 'Telegram'
           WHEN autho_yandex THEN 'Яндекс'
           WHEN autho_google THEN 'Google'
           ELSE 'Без авторизации через соцсети'
       END AS социальная_сеть,
       COUNT(id) AS количество_доноров,
       AVG(confirmed_donations) AS среднее_количество_донаций
FROM donorsearch.user_anon_data
GROUP BY социальная_сеть;


-- Задача 6. Сравнить активность однократных доноров со средней активностью повторных доноров.

-- Группировка по времени: Рассмотреть, как изменяется активность доноров в зависимости от года первой донации.
-- Анализ частоты донаций: Разделить повторных доноров по количеству донаций (например, 2-3, 4-5, 6 и более донаций).
-- Возраст активности доноров: Вычислить, сколько времени прошло с первой донации до текущего момента, чтобы понять, насколько давними являются активные доноры.

WITH donor_activity AS (
  SELECT user_id,
         COUNT(*) AS total_donations,
         (MAX(donation_date) - MIN(donation_date)) AS activity_duration_days,
         (MAX(donation_date) - MIN(donation_date)) / (COUNT(*) - 1) AS avg_days_between_donations,
         EXTRACT(YEAR FROM MIN(donation_date)) AS first_donation_year,
         EXTRACT(YEAR FROM AGE(CURRENT_DATE, MIN(donation_date))) AS years_since_first_donation
  FROM donorsearch.donation_anon
  GROUP BY user_id
  HAVING COUNT(*) > 1
)
SELECT first_donation_year,
       CASE 
           WHEN total_donations BETWEEN 2 AND 3 THEN '2-3 донации'
           WHEN total_donations BETWEEN 4 AND 5 THEN '4-5 донаций'
           ELSE '6 и более донаций'
       END AS donation_frequency_group,
       COUNT(user_id) AS donor_count,
       AVG(total_donations) AS avg_donations_per_donor,
       AVG(activity_duration_days) AS avg_activity_duration_days,
       AVG(avg_days_between_donations) AS avg_days_between_donations,
       AVG(years_since_first_donation) AS avg_years_since_first_donation
FROM donor_activity
GROUP BY first_donation_year, donation_frequency_group
ORDER BY first_donation_year, donation_frequency_group;
  

-- Задача 7. Проанализировать планирования доноров и их реальной активности
WITH planned_donations AS (
  SELECT DISTINCT user_id, donation_date, donation_type
  FROM donorsearch.donation_plan
),
actual_donations AS (
  SELECT DISTINCT user_id, donation_date
  FROM donorsearch.donation_anon
),
planned_vs_actual AS (
  SELECT
    pd.user_id,
    pd.donation_date AS planned_date,
    pd.donation_type,
    CASE WHEN ad.user_id IS NOT NULL THEN 1 ELSE 0 END AS completed
  FROM planned_donations pd
  LEFT JOIN actual_donations ad ON pd.user_id = ad.user_id AND pd.donation_date = ad.donation_date
)
SELECT
  donation_type,
  COUNT(*) AS total_planned_donations,
  SUM(completed) AS completed_donations,
  ROUND(SUM(completed) * 100.0 / COUNT(*), 2) AS completion_rate
FROM planned_vs_actual
GROUP BY donation_type;




