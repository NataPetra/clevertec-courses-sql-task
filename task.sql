-- Вывести к каждому самолету класс обслуживания и количество мест этого класса

SELECT s.aircraft_code, s.fare_conditions AS class_of_service, COUNT(s.seat_no) AS seat_count
FROM seats s
GROUP BY s.aircraft_code, s.fare_conditions;

-- Найти 3 самых вместительных самолета (модель + кол-во мест)

WITH seat_counts AS (
    SELECT s.aircraft_code, COUNT(s.seat_no) AS seat_count
    FROM seats s
    GROUP BY s.aircraft_code
)

SELECT ad.model AS "Aircraft model", sc.seat_count
FROM aircrafts_data ad
         JOIN seat_counts sc ON ad.aircraft_code = sc.aircraft_code
ORDER BY sc.seat_count DESC
LIMIT 3;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам

SELECT
    s.aircraft_code,
    ad.model->>'ru' AS "Aircraft model (RU)",
    s.seat_no
FROM seats s
         JOIN aircrafts_data ad ON s.aircraft_code = ad.aircraft_code
WHERE ad.model->>'ru' = 'Аэробус A321-200'
  AND (s.fare_conditions = 'Business' OR s.fare_conditions = 'Comfort')
ORDER BY s.seat_no;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)

SELECT
    a.airport_code AS "Код аэропорта",
    a.airport_name->>'ru' AS "Аэропорт",
    a.city->>'ru' AS "Город"
FROM airports_data a
WHERE a.city->>'ru' IN (
    SELECT city->>'ru'
    FROM airports_data
    GROUP BY city->>'ru'
    HAVING COUNT(*) > 1
);

-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация

SELECT
    flight_id,
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

WITH extremeTickets AS (
    SELECT
        tf.ticket_no,
        tf.amount,
        ROW_NUMBER() OVER (ORDER BY tf.amount) AS cheapest,
        ROW_NUMBER() OVER (ORDER BY tf.amount DESC) AS expensive
    FROM
        ticket_flights tf
)
SELECT
    CASE
        WHEN cheapest = 1 THEN 'Самый дешевый билет'
        WHEN expensive = 1 THEN 'Самый дорогой билет'
        END AS description,
    ticket_no,
    amount AS cost
FROM extremeTickets
WHERE cheapest = 1 OR expensive = 1;

--выводит все самые дешовые и самы дорогие

WITH extremeTickets AS (
    SELECT
        tf.ticket_no,
        tf.amount,
        MIN(tf.amount) OVER () AS min_amount,
        MAX(tf.amount) OVER () AS max_amount
    FROM ticket_flights tf
)
SELECT
    CASE
        WHEN amount = min_amount THEN 'Самый дешевый билет'
        WHEN amount = max_amount THEN 'Самый дорогой билет'
        END AS description,
    ticket_no,
    amount AS cost
FROM extremeTickets
WHERE amount = min_amount OR amount = max_amount;


-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов

WITH FlightTotalCost AS (
    SELECT
        tf.flight_id,
        SUM(tf.amount) AS total_cost
    FROM
        ticket_flights tf
    GROUP BY tf.flight_id
)
SELECT
    f.flight_id,
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
FROM
    flights f
        JOIN FlightTotalCost FTC ON f.flight_id = FTC.flight_id
ORDER BY FTC.total_cost DESC
LIMIT 1;


-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость

SELECT
    ad.aircraft_code,
    ad.model,
    SUM(tf.amount) AS total_profit
FROM
    aircrafts_data ad
        JOIN flights f ON ad.aircraft_code = f.aircraft_code
        JOIN ticket_flights tf ON f.flight_id = tf.flight_id
GROUP BY ad.aircraft_code
ORDER BY total_profit DESC
LIMIT 1;

-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город

WITH modelAirportCounts AS (
    SELECT
        ad.model AS aircraft_model,
        f.arrival_airport,
        COUNT(*) AS flight_count
    FROM
        aircrafts ad
            JOIN flights f ON ad.aircraft_code = f.aircraft_code
    GROUP BY ad.model, f.arrival_airport
),
     airportCountsList AS (
         SELECT
             aircraft_model,
             arrival_airport,
             flight_count,
             ROW_NUMBER() OVER (PARTITION BY aircraft_model ORDER BY flight_count DESC) AS rank
         FROM modelAirportCounts
     )
SELECT
    AC.aircraft_model,
    AC.flight_count,
    AC.arrival_airport,
    ad.city AS destination_city
FROM airportCountsList AC
         JOIN airports ad ON AC.arrival_airport = ad.airport_code
WHERE AC.rank = 1;
