--- Script to look at journeys to playback from the recomended section on homepage for the experiment iplxp_irex1_model1_1

-- Initially set a date range table for ease of changing later
DROP TABLE IF EXISTS central_insights_sandbox.vb_homepage_rec_date_range;
create table central_insights_sandbox.vb_homepage_rec_date_range (
    min_date varchar(20),
    max_date varchar(20));
insert into central_insights_sandbox.vb_homepage_rec_date_range values
('20200406','20200406');


-----------------------------------------  Identify the user group -----------------------------
-- Identify the users and visits within the exp group.
DROP TABLE IF EXISTS central_insights_sandbox.vb_rec_exp_ids;
CREATE TABLE central_insights_sandbox.vb_rec_exp_ids AS
SELECT DISTINCT b.*,
                CASE
                    WHEN a.user_experience = 'REC=think-personal-iplayer-homepg-tvforyou' THEN 'homepg-tvforyou'
                    WHEN a.user_experience = 'REC=think-personal-iplayer-homepg-tvforyou-ndm' THEN 'homepg-tvforyou-ndm'
                    WHEN a.user_experience = 'REC=think-personal-iplayer-player-tvforyou' THEN 'player-tvforyou'
                    ELSE 'unknown'
                    END AS exp_subgroup
FROM s3_audience.publisher a
         JOIN (SELECT destination,
                      dt,
                      unique_visitor_cookie_id,
                      visit_id,
                      CASE
                          WHEN metadata iLIKE '%iplayer::bigscreen-html%' THEN 'bigscreen'
                          WHEN metadata ILIKE '%responsive::iplayer%' THEN 'web'
                          END AS platform,
                      CASE
                          WHEN user_experience = 'EXP=iplxp_irex1_model1_1::variation_1' THEN 'variation_1'
                          WHEN user_experience = 'EXP=iplxp_irex1_model1_1::variation_2' THEN 'variation_2'
                          WHEN user_experience = 'EXP=iplxp_irex1_model1_1::control' THEN 'control'
                          ELSE 'unknown'
                          END AS exp_group
               FROM s3_audience.publisher
               WHERE dt between (SELECT min_date
                                 FROM central_insights_sandbox.vb_homepage_rec_date_range)
                   AND (SELECT max_date
                        FROM central_insights_sandbox.vb_homepage_rec_date_range)
                 AND user_experience ilike '%iplxp_irex1_model1_1%'
                 AND destination = 'PS_IPLAYER'
                 AND (metadata ILIKE '%iplayer::bigscreen-html%'
                   OR metadata ILIKE '%responsive::iplayer%')
               LIMIT 1000) b
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.visit_id = b.visit_id and a.dt = b.dt AND
                 a.destination = b.destination
WHERE a.destination = 'PS_IPLAYER'
  AND a.dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date
                                                                                                   FROM central_insights_sandbox.vb_homepage_rec_date_range)
  AND (a.user_experience ilike '%REC=think-personal-iplayer-homepg-tvforyou%' OR
       a.user_experience ilike '%REC=think-personal-iplayer-homepg-tvforyou-ndm%' OR
       a.user_experience ilike '%REC=think-personal-iplayer-player-tvforyou%')
  AND (a.metadata ILIKE '%iplayer::bigscreen-html%' OR a.metadata ILIKE '%responsive::iplayer%')
ORDER BY a.dt, a.unique_visitor_cookie_id, a.visit_id;

-- Users can come in with 'cold' recomendations where we know nothing about them so just guess. The field user_experience ilike '%REC=think-%' gives the label to show if they're cold or not.
-- Need to keep and group by these at the end
    -- user_experience =
    -- REC=think-personal-iplayer-homepg-tvforyou
    -- REC=think-personal-iplayer-homepg-tvforyou-ndm
    -- REC=think-personal-iplayer-player-tvforyou
-- This is sent at a different time to to user_experience ilike '%iplxp_irex1_model1_1%' label so need both.

SELECT * FROM central_ins
ights_sandbox.vb_rec_exp_ids LIMIT 100;


-- Add age and hid into sample IDs as user's are categorised based on hid not UV.
-- This will removed non-signed in users (which we want as exp is only for signed in)
DROP TABLE IF EXISTS vb_expIDs;
CREATE TABLE vb_expIDs AS
SELECT DISTINCT id.unique_visitor_cookie_id,
                id.visit_id,
                id.dt,
                id.platform,
                --id.user_experience,
                p.bbc_hid3,
                CASE
                    WHEN p.age >= 35 THEN '35+'
                    WHEN p.age <= 10 THEN 'under 10'
                    WHEN p.age >= 11 AND p.age <= 15 THEN '11-15'
                    WHEN p.age >= 16 AND p.age <= 24 THEN '16-24'
                    WHEN p.age >= 25 AND p.age <= 34 then '25-34'
                    ELSE 'unknown'
                    END AS age_range
FROM vb_expIDs_temp id
         JOIN (SELECT DISTINCT unique_visitor_cookie_id, visit_id, audience_id, dt
               FROM s3_audience.visits
               WHERE destination = 'PS_IPLAYER'
                 AND dt between '20200319' AND '20200326') v
              ON id.unique_visitor_cookie_id = v.unique_visitor_cookie_id AND id.visit_id = v.visit_id AND id.dt = v.dt
         JOIN prez.id_profile p ON v.audience_id = p.bbc_hid3
ORDER BY id.unique_visitor_cookie_id, p.bbc_hid3
;

--- Are any visits lost when adding in age? Difference = 1.1 mil (for 2020-03-25) Non signed in people?
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM vb_expIDs_temp); -- 5,351,874
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM vb_expIDs); -- 4,250,857
--How many UV are lost
SELECT COUNT(*) FROM (SELECT DISTINCT dt, unique_visitor_cookie_id FROM vb_expIDs_temp); -- 4,002,444
SELECT COUNT(*) FROM (SELECT DISTINCT dt, unique_visitor_cookie_id FROM vb_expIDs); -- 3,188,489

--by platform
SELECT platform, COUNT(*) FROM (SELECT DISTINCT dt, platform, visit_id FROM vb_expIDs_temp) GROUP BY platform;
--platform,count
-- web,  1,524,632
-- bigscreen, 3,827,307

SELECT platform, COUNT(*) FROM (SELECT DISTINCT dt, platform, visit_id FROM vb_expIDs) GROUP BY platform;
--platform,count
-- web,   1,089,276
-- bigscreen,  3,161,633



-- How many hids have more than one age range? SHOULD be as close to zero as possible
SELECT COUNT(*)
FROM (SELECT DISTINCT bbc_hid3, count(DISTINCT age_range) AS num_age_ranges
      FROM vb_expIDs
      GROUP BY bbc_hid3
      HAVING count(DISTINCT age_range) > 1); --ZERO!!


-- Get all impressions to the module as a whole
DROP TABLE IF EXISTS vb_module_impressions;
CREATE TABLE vb_module_impressions AS
SELECT DISTINCT b.dt,
                b.unique_visitor_cookie_id,
                b.bbc_hid3,
                b.platform,
                b.age_range,
                b.visit_id,
                CASE
                    WHEN a.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
                    ELSE a.container END AS container
FROM s3_audience.publisher a
        RIGHT JOIN vb_expIDs b ON a.dt = b.dt
    AND a.visit_id = b.visit_id AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id
WHERE a.destination = 'PS_IPLAYER'
  AND (a.dt between '20200319' AND '20200326')
  AND a.publisher_impressions = 1
  AND placement = 'iplayer.tv.page';

SELECT * FROM vb_module_impressions ORDER BY unique_visitor_cookie_id,
                bbc_hid3 limit 50 ;
SELECT * FROM s3_audience.publisher WHERE destination = 'PS_IPLAYER' LIMIT 3;



-- Counts - all modules
SELECT dt, platform, container, age_range, count(*) AS count_module_views
FROM vb_module_impressions
GROUP BY dt, platform,container, age_range
;


-- Select all publisher data for these users
DROP TABLE IF EXISTS vb_rec_exp_data;
CREATE TABLE vb_rec_exp_data AS
SELECT a.bbc_hid3,
       a.dt,
       a.visit_id,
       a.platform,
       b.event_position,
       b.container,
       b.attribute,
       b.placement,
       b.result,
       b.publisher_clicks,
       b.publisher_impressions,
       b.event_start_datetime
FROM vb_expids a
         JOIN s3_audience.publisher b ON a.dt = b.dt
    AND a.visit_id = b.visit_id AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id
WHERE b.destination = 'PS_IPLAYER'
  AND (b.metadata LIKE '%iplayer::bigscreen-html%' OR b.metadata LIKE '%responsive::iplayer%')
  AND b.dt BETWEEN '20200319' AND '20200326';

-- Select all the entries where content was played to give the flag 'iplxp-ep-started'
DROP TABLE IF EXISTS vb_rec_exp_play_starts;
CREATE TABLE vb_rec_exp_play_starts AS
SELECT DISTINCT a.dt,
                a.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.container,
                a.attribute,
                a.placement,
                a.result,
                a.platform,
                b.brand_id,
                b.series_id
FROM vb_rec_exp_data a
         JOIN prez.scv_vmb b ON a.result = b.episode_id
WHERE a.publisher_impressions = 1
  and a.attribute = 'iplxp-ep-started'
ORDER BY a.dt, a.bbc_hid3, a.visit_id, a.event_position;

SELECT * FROM vb_rec_exp_data LIMIT 10
;

-- Join the starts to any content item click that came before them.
-- Check the same dt, UV and visit id.
-- Ensure that the content result is the brand, series or episode id that was started.
DROP TABLE IF EXISTS vb_rec_exp_valid_starts_temp;
CREATE TABLE vb_rec_exp_valid_starts_temp AS
SELECT a.dt,
       a.bbc_hid3,
       a.visit_id,
       a.event_position                                     AS content_event_position,
       CASE
           WHEN b.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
           ELSE b.container END                             AS container,
       a.attribute                                          AS content_attribute,
       a.result                                             AS content_result,
       a.event_position                                     AS start_event_position,
       a.attribute                                          AS start_attribute,
       a.result                                             AS start_result,
       a.brand_id,
       a.series_id,
       a.platform,
       CAST(a.event_position - b.event_position AS integer) AS content_start_diff
FROM vb_rec_exp_play_starts a
         INNER JOIN vb_rec_exp_data b
                    ON a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
WHERE b.attribute LIKE 'content_item'
  AND b.publisher_clicks = 1
  AND b.event_position < a.event_position
  AND b.placement = 'iplayer.tv.page'
  AND (b.result = a.result OR b.result = a.brand_id OR b.result = a.series_id);


DROP TABLE IF EXISTS vb_rec_exp_valid_starts;
CREATE TABLE vb_rec_exp_valid_starts AS
SELECT *
FROM (SELECT *,
             row_number()
             OVER (PARTITION BY dt, bbc_hid3, visit_id, start_event_position ORDER BY content_start_diff) AS duplicate_identifier
      FROM vb_rec_exp_valid_starts_temp
      ORDER BY bbc_hid3, visit_id, start_event_position)
WHERE duplicate_identifier = 1;



-- How many starts
SELECT a.platform, a.container, b.age_range, count(a.start_result)
FROM vb_rec_exp_valid_starts a
JOIN vb_expIDs b ON a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
GROUP BY a.platform,a.container, b.age_range;

-- Starts per age
SELECT container, count(start_result)
FROM vb_rec_exp_valid_starts
GROUP BY container;


--- How many made it all the way through content to the watched flag
DROP TABLE IF EXISTS vb_rec_exp_play_watched;
CREATE TABLE vb_rec_exp_play_watched AS
SELECT DISTINCT a.dt,
                a.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.container,
                a.attribute,
                a.placement,
                a.result,
                b.brand_id,
                b.series_id
FROM vb_rec_exp_data a
         JOIN prez.scv_vmb b ON a.result = b.episode_id
WHERE a.publisher_impressions = 1
  and a.attribute = 'iplxp-ep-watched'
ORDER BY a.dt, a.bbc_hid3, a.visit_id, a.event_position;

-- Join the watch events to the validated start events, ensuring the same episode ID
DROP TABLE IF EXISTS vb_rec_exp_valid_watched_temp;
CREATE TABLE vb_rec_exp_valid_watched_temp AS
         SELECT a.dt,
                a.bbc_hid3,
                a.visit_id,
                a.content_event_position,
                a.container,
                a.content_attribute,
                a.content_result,
                a.start_event_position,
                a.start_result,
                a.platform,
                b.attribute      AS watched_attribute,
                b.result         AS watched_result,
                b.event_position AS watched_event_position,
                CAST(b.event_position-a.start_event_position AS integer) AS start_watched_diff
         FROM vb_rec_exp_valid_starts a
                  JOIN vb_rec_exp_play_watched b on a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
         WHERE  a.start_event_position < b.event_position
           AND a.start_result = b.result;


-- Validate to ensure no duplicates. Select the start nearest to the watched event.
DROP TABLE IF EXISTS vb_rec_exp_valid_watched;
CREATE TABLE vb_rec_exp_valid_watched AS
SELECT *
FROM (SELECT *,
             row_number()
             OVER (PARTITION BY dt, bbc_hid3, visit_id, watched_event_position ORDER BY start_watched_diff) AS duplicate_identifier
      FROM vb_rec_exp_valid_watched_temp
      ORDER BY bbc_hid3, visit_id, start_event_position)
WHERE duplicate_identifier = 1;

SELECT a.platform, a.container, b.age_range, count(a.watched_result)
FROM vb_rec_exp_valid_watched a
JOIN vb_expIDs b ON a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
GROUP BY a.platform, a.container, b.age_range LIMIT 5;


SELECT dt, container, count(start_result) AS num_starts FROM vb_rec_exp_valid_starts GROUP BY dt, container;
SELECT container, count(watched_result) AS num_watched FROM vb_rec_exp_valid_watched  GROUP BY container;

SELECT * FROM vb_rec_exp_valid_starts  LIMIT 5;

-- Complete table - web
DROP TABLE IF EXISTS vb_all_module_summary;
CREATE TABLE vb_all_module_summary AS
SELECT a.dt, a.bbc_hid3, a.visit_id, a.container, b.age_range, c.start_result, d.watched_result
FROM vb_module_impressions a
         JOIN vb_expIDs b ON a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
         LEFT JOIN (SELECT dt, bbc_hid3, visit_id, container, start_result
                    FROM vb_rec_exp_valid_starts
                    WHERE platform = 'web') c
                   ON a.dt = c.dt AND a.visit_id = c.visit_id AND a.bbc_hid3 = c.bbc_hid3 AND a.container = c.container
LEFT JOIN (SELECT dt, bbc_hid3, visit_id, container, watched_result
                    FROM vb_rec_exp_valid_watched
                    WHERE platform = 'web') d
                   ON a.dt = d.dt AND a.visit_id = d.visit_id AND a.bbc_hid3 = d.bbc_hid3 AND a.container = d.container AND c.start_result = d.watched_result
WHERE a.platform = 'web';

-- Complete table - bigscreen
DROP TABLE IF EXISTS vb_all_module_summary_bigscreen;
CREATE TABLE vb_all_module_summary_bigscreen AS
SELECT a.dt, a.bbc_hid3, a.visit_id, a.container, b.age_range, a.start_result, d.watched_result
FROM vb_rec_exp_valid_starts a
JOIN vb_expIDs b ON a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
LEFT JOIN (SELECT dt, bbc_hid3, visit_id, container, watched_result
                    FROM vb_rec_exp_valid_watched
                    WHERE platform = 'bigscreen') d
                   ON a.dt = d.dt AND a.visit_id = d.visit_id AND a.bbc_hid3 = d.bbc_hid3 AND a.container = d.container AND a.start_result = d.watched_result
WHERE a.platform = 'bigscreen';


SELECT * FROM vb_all_module_summary
WHERE age_range = '16-24' ANd start_result IS NOT NULL AND watched_result IS NOT NULL
ORDER BY dt, age_range, container LIMIT 100 ;


-- Web summary
SELECT dt,
       age_range,
       container,
       count(bbc_hid3)       AS num_impressions,
       count(start_result)   AS num_start_results,
       count(watched_result) AS num_watched_result
FROM vb_all_module_summary
GROUP BY dt, age_range, container;

-- bigscreen summary
SELECT dt,
       age_range,
       container,
       count(start_result)   AS num_start_results,
       count(watched_result) AS num_watched_result
FROM vb_all_module_summary_bigscreen
GROUP BY dt, age_range, container;

