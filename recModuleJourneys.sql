--- Get sample of users
DROP TABLE IF EXISTS vb_expIDs_temp;
CREATE TABLE vb_expIDs_temp AS
SELECT DISTINCT dt,
                unique_visitor_cookie_id,
                visit_id
                --CASE
                --    WHEN user_experience LIKE 'EXP=iplxp_ibl32_sort_featured::control' THEN 'control'
                --    WHEN user_experience LIKE 'EXP=iplxp_ibl32_sort_featured::test'
                --        THEN 'test' END AS user_experience
FROM s3_audience.publisher
WHERE --user_experience LIKE '%iplxp_ibl32_sort_featured::%' AND
    (metadata LIKE '%iplayer::bigscreen-html%' OR metadata LIKE '%responsive::iplayer%')
  AND dt BETWEEN '20200319' AND '20200325'
  AND destination = 'PS_IPLAYER';

DROP TABLE IF EXISTS vb_expIDs;
CREATE TABLE vb_expIDs AS
SELECT DISTINCT id.unique_visitor_cookie_id,
                id.visit_id,
                id.dt,
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
                 AND dt BETWEEN '20200319' AND '20200325') v
              ON id.unique_visitor_cookie_id = v.unique_visitor_cookie_id AND id.visit_id = v.visit_id AND id.dt = v.dt
         JOIN prez.id_profile p ON v.audience_id = p.bbc_hid3
;

SELECT * FROM vb_expIDs WHERE bbc_hid3 ISNULL LIMIT 100;
--- Are any visits lost when adding in age? Difference = 1.1 mil (for 2020-03-25)
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM vb_expIDs_temp); -- 5,351,874
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM vb_expIDs); -- 4,250,857

-- How many hids have more than one age range? SHOULD be as close to zero as possible
SELECT COUNT(*)
FROM (SELECT DISTINCT bbc_hid3, count(DISTINCT age_range) AS num_age_ranges
      FROM vb_expIDs
      GROUP BY bbc_hid3
      HAVING count(DISTINCT age_range) > 1); --ZERO!!


-- Get all impressions to the module as a whole
DROP TABLE IF EXISTS vb_module_impressions;
CREATE TABLE vb_module_impressions AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                b.age_range,
                a.visit_id,
                a.placement,
                a.container,
                a.publisher_clicks,
                a.publisher_impressions
FROM s3_audience.publisher a
         JOIN vb_expIDs b ON a.dt = b.dt
    AND a.visit_id = b.visit_id AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id
WHERE a.destination = 'PS_IPLAYER'
  AND (metadata LIKE '%iplayer::bigscreen-html%' OR metadata LIKE '%responsive::iplayer%')
  AND a.dt = '20200325'
  AND a.publisher_impressions = 1
AND placement ='iplayer.tv.page' ;

SELECT * FROM s3_audience.publisher WHERE destination = 'PS_IPLAYER' LIMIT 3;

-- Counts
SELECT dt, container, age_range, count(*) AS count_module_views
FROM vb_module_impressions
WHERE container ILIKE '%module-recommendations-recommended-for-you%'
GROUP BY dt, container, age_range
;


-- Select everything for those users who saw the module
DROP TABLE IF EXISTS vb_rec_exp_data;
CREATE TABLE vb_rec_exp_data AS
SELECT a.bbc_hid3,
       a.dt,
       a.visit_id,
       b.event_position,
       a.container,
       b.attribute,
       a.placement,
       b.result,
       b.publisher_clicks,
       b.publisher_impressions,
       b.event_start_datetime
FROM vb_module_impressions a
         JOIN s3_audience.publisher b ON a.dt = b.dt
    AND a.visit_id = b.visit_id AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id
WHERE b.destination = 'PS_IPLAYER'
  AND (b.metadata LIKE '%iplayer::bigscreen-html%' OR b.metadata LIKE '%responsive::iplayer%')
  AND b.dt = '20200325';

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
                b.brand_id,
                b.series_id
FROM vb_rec_exp_data a
         JOIN prez.scv_vmb b ON a.result = b.episode_id
WHERE a.publisher_impressions = 1
  and a.attribute = 'iplxp-ep-started'
ORDER BY a.dt, a.bbc_hid3, a.visit_id, a.event_position;


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
           WHEN a.container ILIKE '%module-recommendations-recommended-for-you%' THEN 'rec_module'
           WHEN a.container NOT LIKE '%module-recommendations-recommended-for-you%' THEN 'not_rec_module'
           END                                              AS container,
       a.attribute                                          AS content_attribute,
       a.result                                             AS content_result,
       a.event_position                                     AS start_event_position,
       a.attribute                                          AS start_attribute,
       a.result                                             AS start_result,
       a.brand_id,
       a.series_id,
       CAST(a.event_position - a.event_position AS integer) AS content_start_diff
FROM vb_rec_exp_play_starts a
         INNER JOIN vb_rec_exp_data b
                    ON  a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
WHERE b.attribute LIKE 'content_item'
  AND b.publisher_clicks = 1
  AND b.event_position > a.event_position
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



-- How many starts -- 419 starts
SELECT a.container, b.age_range, count(a.start_result)
FROM vb_rec_exp_valid_starts a
JOIN vb_module_impressions b ON a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
GROUP BY a.container, b.age_range;

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
                b.attribute      AS watched_attribute,
                b.result         AS watched_result,
                b.event_position AS watched_event_position,
                CAST(b.event_position-a.start_event_position AS integer) AS start_watched_diff
         FROM vb_rec_exp_valid_starts a
                  JOIN vb_rec_exp_play_watched b on a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
         WHERE  a.start_event_position < b.event_position
           AND a.start_result = b.result;


-- Validate to ensure no duplicates. Select the start nearest to the watched event.
DROP TABLE IF EXISTS vb_rec_exp_valid_watched_temp;
CREATE TABLE vb_rec_exp_valid_watched AS
SELECT *
FROM (SELECT *,
             row_number()
             OVER (PARTITION BY dt, bbc_hid3, visit_id, watched_event_position ORDER BY start_watched_diff) AS duplicate_identifier
      FROM vb_rec_exp_valid_watched_temp
      ORDER BY bbc_hid3, visit_id, start_event_position)
WHERE duplicate_identifier = 1;

SELECT a.container, b.age_range, count(a.watched_result)
FROM vb_rec_exp_valid_watched a
JOIN vb_module_impressions b ON a.dt = b.dt AND a.visit_id = b.visit_id AND a.bbc_hid3 = b.bbc_hid3
GROUP BY a.container, b.age_range;


SELECT container, count(start_result) AS num_starts FROM vb_rec_exp_valid_starts GROUP BY container;
SELECT container, count(watched_result) AS num_watched FROM vb_rec_exp_valid_watched  GROUP BY container;
