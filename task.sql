-- Вывести к каждому самолету класс обслуживания и количество мест этого класса

SELECT s.aircraft_code, s.fare_conditions AS class_of_service, COUNT(s.seat_no) AS seat_count
FROM seats s
GROUP BY s.aircraft_code, s.fare_conditions;

-- Найти 3 самых вместительных самолета (модель + кол-во мест)

SELECT a.model  AS "Aircraft Model",
       COUNT(*) AS "Total Seats"
FROM seats s
         JOIN aircrafts a ON s.aircraft_code = a.aircraft_code
GROUP BY a.model
ORDER BY "Total Seats" DESC
LIMIT 3;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам

SELECT s.aircraft_code,
       ad.model ->> 'ru' AS "Aircraft model (RU)",
       s.seat_no
FROM seats s
         JOIN aircrafts_data ad ON s.aircraft_code = ad.aircraft_code
WHERE ad.model ->> 'ru' = 'Аэробус A321-200'
  AND s.fare_conditions != 'Economy'
ORDER BY s.seat_no;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)

SELECT a.airport_code          AS "Код аэропорта",
       a.airport_name ->> 'ru' AS "Аэропорт",
       a.city ->> 'ru'         AS "Город"
FROM airports_data a
WHERE a.city ->> 'ru' IN (SELECT city ->> 'ru'
                          FROM airports_data
                          GROUP BY city ->> 'ru'
                          HAVING COUNT(*) > 1);

-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация

SELECT flight_id,
       flight_no,
       scheduled_departure_local,
       departure_airport_name,
       arrival_airport_name,
       status
FROM flights_v
WHERE departure_city = 'Екатеринбург'
  AND arrival_city = 'Москва'
  AND status = 'Scheduled'
  AND scheduled_departure_local > '2017-08-17 10:08:00'
ORDER BY scheduled_departure_local
LIMIT 1;

-- Вывести самый дешевый и дорогой билет и стоимость ( в одном результирующем ответе)

--выводит 1 самый дорогой и 1 самый дешовый

(SELECT tf.ticket_no, tf.amount
 FROM ticket_flights tf
 ORDER BY tf.amount
 LIMIT 1)
UNION ALL
(SELECT tf.ticket_no, tf.amount
 FROM ticket_flights tf
 ORDER BY tf.amount DESC
 LIMIT 1);

--выводит все самые дешовые и самы дорогие

WITH extremeTickets AS (SELECT tf.ticket_no,
                               tf.amount,
                               MIN(tf.amount) OVER () AS min_amount,
                               MAX(tf.amount) OVER () AS max_amount
                        FROM ticket_flights tf)
SELECT CASE
           WHEN amount = min_amount THEN 'Самый дешевый билет'
           WHEN amount = max_amount THEN 'Самый дорогой билет'
           END AS description,
       ticket_no,
       amount  AS cost
FROM extremeTickets
WHERE amount = min_amount
   OR amount = max_amount;

-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов

WITH FlightTotalCost AS (SELECT tf.flight_id,
                                SUM(tf.amount) AS total_cost
                         FROM ticket_flights tf
                         GROUP BY tf.flight_id)
SELECT f.flight_id,
       f.flight_no,
       f.scheduled_departure,
       f.scheduled_arrival,
       f.departure_airport,
       f.arrival_airport,
       f.aircraft_code,
       f.actual_departure,
       f.actual_arrival,
       f.status,
       FTC.total_cost
FROM flights f
         JOIN FlightTotalCost FTC ON f.flight_id = FTC.flight_id
WHERE FTC.total_cost = (SELECT MAX(total_cost)
                        FROM FlightTotalCost);

-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость

WITH AircraftProfit AS (SELECT ad.aircraft_code,
                               ad.model,
                               SUM(tf.amount) AS total_profit
                        FROM aircrafts_data ad
                                 JOIN flights f ON ad.aircraft_code = f.aircraft_code
                                 JOIN ticket_flights tf ON f.flight_id = tf.flight_id
                        GROUP BY ad.aircraft_code, ad.model)
SELECT ap.aircraft_code,
       ap.model,
       ap.total_profit
FROM AircraftProfit ap
WHERE ap.total_profit = (SELECT MAX(total_profit)
                         FROM AircraftProfit);

-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город

SELECT ad.model,
       a.airport_code,
       a.city,
       COUNT(*) AS flight_count
FROM flights f
         JOIN aircrafts_data ad ON f.aircraft_code = ad.aircraft_code
         JOIN airports a ON f.arrival_airport = a.airport_code
GROUP BY ad.model,
         a.airport_code,
         a.city
HAVING COUNT(*) = (SELECT MAX(flight_count)
                   FROM (SELECT ad.model,
                                a.airport_code,
                                COUNT(*) AS flight_count
                         FROM flights f
                                  JOIN aircrafts_data ad ON f.aircraft_code = ad.aircraft_code
                                  JOIN airports a ON f.arrival_airport = a.airport_code
                         GROUP BY ad.model,
                                  a.airport_code) AS sub
                   WHERE sub.model = ad.model);

