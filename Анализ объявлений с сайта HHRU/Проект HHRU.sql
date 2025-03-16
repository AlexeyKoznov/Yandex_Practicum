-- Получение статистики по заработной плате
SELECT ROUND(AVG(salary_from), 2) AS avg_salary_from,
       ROUND(AVG(salary_to), 2) AS avg_salary_to,
       MIN(salary_from) AS min_salary_from,
       MAX(salary_from) AS max_salary_from,
       MIN(salary_to) AS min_salary_to,
       MAX(salary_to) AS max_salary_to
FROM public.parcing_table;



-- Количество вакансий по регионам
SELECT area,
       COUNT(*) AS num_vacancies
FROM public.parcing_table
GROUP BY area
ORDER BY num_vacancies DESC;



-- Количество вакансий по компаниям
SELECT employer,
       COUNT(*) AS num_vacancies 
FROM public.parcing_table 
GROUP BY employer 
ORDER BY num_vacancies DESC;



-- Количество вакансий по типу занятости
SELECT employment,
       COUNT(*) AS num_vacancies
FROM public.parcing_table 
GROUP BY employment 
ORDER BY num_vacancies DESC;



-- Количество вакансий по графику работы
SELECT schedule,
       COUNT(*) AS num_vacancies 
FROM public.parcing_table 
GROUP BY schedule 
ORDER BY num_vacancies DESC;



-- Выявление грейда требуемых специалистов по опыту
SELECT experience,
       COUNT(*) AS num_vacancies
FROM public.parcing_table 
GROUP BY experience 
ORDER BY num_vacancies DESC;


-- Определение доли грейдов среди вакансий аналитиков

-- Чтобы это сделать, нам понадобится два запроса:

-- 1) Сначала нужно вычислить общее количество вакансий вручную:

SELECT COUNT(*) 
FROM public.parcing_table 
WHERE name LIKE '%Аналитик данных%' 
   OR name LIKE '%Системный аналитик%';

-- Результат - 1157. 
-- 2) Теперь используем это число чтобы рассчитать доли:

SELECT experience,
       COUNT(*) AS num_vacancies,
       ROUND(COUNT(*) * 100.0 / 1157, 2) AS percent_vacancies
FROM public.parcing_table
WHERE name LIKE '%Аналитик данных%' 
   OR name LIKE '%Системный аналитик%'
GROUP BY experience
ORDER BY percent_vacancies DESC;

-- Определение типичного места работы для аналитиков по различным параметрам
SELECT employer,
       COUNT(*) AS num_vacancies,
       ROUND(AVG(salary_from), 2) AS avg_salary_from,
       ROUND(AVG(salary_to), 2) AS avg_salary_to,
       employment,
       schedule
FROM public.parcing_table 
WHERE name LIKE '%Аналитик данных%' OR name LIKE '%Системный аналитик%'
GROUP BY employer, employment, schedule 
ORDER BY num_vacancies DESC;



-- Частота упоминания hard и soft skills (пример для key_skills_1) (Аналогично для остальных столбцов key_skills и soft_skills)
SELECT key_skills_1,
       COUNT(*) AS num_mention
FROM public.parcing_table 
GROUP BY key_skills_1 
ORDER BY num_mention DESC;
