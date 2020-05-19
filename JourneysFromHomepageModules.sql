--- Script to look at journeys to playback from the recommended section on homepage for the experiment iplxp_irex1_model1_1

-- Initially set a date range table for ease of changing later
DROP TABLE IF EXISTS central_insights_sandbox.vb_homepage_rec_date_range;
create table central_insights_sandbox.vb_homepage_rec_date_range (
    min_date varchar(20),
    max_date varchar(20));
insert into central_insights_sandbox.vb_homepage_rec_date_range values
('20200406','20200412');
-- 2020-04-06 to 2020-05-18

--SELECT * FROM central_insights_sandbox.vb_homepage_rec_date_range;
--2020-04-06 to

-----------------------------------------  Identify the user group -----------------------------

-- Identify the users and visits within the exp groups for the experiment flag '%iplxp_irex1_model1_1%'
DROP TABLE IF EXISTS central_insights_sandbox.vb_rec_exp_ids_temp;
CREATE TABLE central_insights_sandbox.vb_rec_exp_ids_temp AS
    SELECT DISTINCT destination, --gives all the visits in the experiment
                      dt,
                      unique_visitor_cookie_id,
                      visit_id,
                      CASE
                          WHEN metadata iLIKE '%iplayer::bigscreen-html%' THEN 'bigscreen'
                          WHEN metadata ILIKE '%responsive::iplayer%' THEN 'web'
                          --WHEN metadata ILIKE '%mobile%' THEN 'mobile'
                          END AS platform,
                      CASE
                          WHEN user_experience = 'EXP=iplxp_irex1_model1_1::variation_1' THEN 'variation_1'
                          WHEN user_experience = 'EXP=iplxp_irex1_model1_1::variation_2' THEN 'variation_2'
                          WHEN user_experience = 'EXP=iplxp_irex1_model1_1::control' THEN 'control'
                          ELSE 'unknown'
                          END AS exp_group
               FROM s3_audience.publisher
               WHERE dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
                   AND (SELECT max_date  FROM central_insights_sandbox.vb_homepage_rec_date_range)
                 AND user_experience ilike '%iplxp_irex1_model1_1%'
                 AND destination = 'PS_IPLAYER'
                 AND (metadata ILIKE '%iplayer::bigscreen-html%'
                   OR metadata ILIKE '%responsive::iplayer%');

SELECT count(*) FROM central_insights_sandbox.vb_rec_exp_ids_temp WHERE dt = 20200427;
--SELECT * FROM central_insights_sandbox.vb_rec_exp_ids_temp LIMIT 20;
DROP TABLE IF EXISTS central_insights_sandbox.vb_rec_exp_ids;
CREATE TABLE central_insights_sandbox.vb_rec_exp_ids AS
    SELECT * FROM central_insights_sandbox.vb_rec_exp_ids_temp;

-- Issue with finding what think analytics group they're in. For now just keep the variant group.

/*DROP TABLE IF EXISTS central_insights_sandbox.vb_rec_exp_ids;
CREATE TABLE central_insights_sandbox.vb_rec_exp_ids AS
SELECT DISTINCT a.*,
       ISNULL(b.user_experience, 'unknown') AS exp_subgroup
FROM central_insights_sandbox.vb_rec_exp_ids_temp a
         LEFT JOIN s3_audience.publisher b
                   ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                      a.visit_id = b.visit_id
WHERE b.destination = 'PS_IPLAYER'
  AND (b.user_experience ILIKE '%REC=think%' OR
       b.user_experience ILIKE 'REC=irex%') --find out what think group they're in, or the in house group
  AND b.container = 'module-recommendations-recommended-for-you'
  AND b.dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date
                                                                                                   FROM central_insights_sandbox.vb_homepage_rec_date_range)
  AND (b.metadata ILIKE '%iplayer::bigscreen-html%' OR b.metadata ILIKE '%responsive::iplayer%')

SELECT count(*) FROM central_insights_sandbox.vb_rec_exp_ids;
SELECT * FROM central_insights_sandbox.vb_rec_exp_ids WHERE exp_subgroup ISNULL;

DROP TABLE IF EXISTS central_insights_sandbox.vb_rec_exp_ids;
CREATE TABLE central_insights_sandbox.vb_rec_exp_ids AS
SELECT DISTINCT b.*,
                a.user_experience  AS exp_subgroup -- for the visits in the exp, gives what rec they've got from think analytics
FROM s3_audience.publisher a
         RIGHT JOIN (SELECT destination, --gives all the visits in the experiment
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
               WHERE dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
                   AND (SELECT max_date  FROM central_insights_sandbox.vb_homepage_rec_date_range)
                 AND user_experience ilike '%iplxp_irex1_model1_1%'
                 AND destination = 'PS_IPLAYER'
                 AND (metadata ILIKE '%iplayer::bigscreen-html%'
                   OR metadata ILIKE '%responsive::iplayer%')) b
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.visit_id = b.visit_id and a.dt = b.dt AND
                 a.destination = b.destination
WHERE a.destination = 'PS_IPLAYER'
  AND (user_experience ILIKE '%REC=think%' OR user_experience ILIKE 'REC=irex%') --find out what think group they're in, or the in house group
  AND a.container = 'module-recommendations-recommended-for-you'
  AND a.dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
  AND (a.metadata ILIKE '%iplayer::bigscreen-html%' OR a.metadata ILIKE '%responsive::iplayer%')
ORDER BY a.dt, a.unique_visitor_cookie_id, a.visit_id;

SELECT count(*) FROM central_insights_sandbox.vb_rec_exp_ids;*/

-- Add age and hid into sample IDs as user's are categorised based on hid not UV.
-- This will removed non-signed in users (which we want as exp is only for signed in)
DROP TABLE IF EXISTS central_insights_sandbox.vb_rec_exp_ids_hid;
CREATE TABLE central_insights_sandbox.vb_rec_exp_ids_hid  AS
SELECT DISTINCT a.*,
                c.bbc_hid3,
                CASE
                    WHEN c.age >= 35 THEN '35+'
                    WHEN c.age <= 10 THEN 'under 10'
                    WHEN c.age >= 11 AND c.age <= 15 THEN '11-15'
                    WHEN c.age >= 16 AND c.age <= 24 THEN '16-24'
                    WHEN c.age >= 25 AND c.age <= 34 then '25-34'
                    ELSE 'unknown'
                    END AS age_range
FROM central_insights_sandbox.vb_rec_exp_ids a -- all the IDs from publisher
         JOIN (SELECT DISTINCT dt, unique_visitor_cookie_id, visit_id, audience_id, destination
               FROM s3_audience.visits
               WHERE destination = 'PS_IPLAYER' AND dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date
                                                                                                   FROM central_insights_sandbox.vb_homepage_rec_date_range)) b -- get the audience_id
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.visit_id = b.visit_id AND a.dt = b.dt AND a.destination = b.destination
         JOIN prez.id_profile c ON b.audience_id = c.bbc_hid3
ORDER BY a.dt, c.bbc_hid3, visit_id
;

-- Some visits end up sending two or three experiment flags. When the signed in user is switched.
-- For 2020-04-06 to 2020-04-27 the number of bbc3_hids/visit combinations with more than one ID was 0.8%.
-- These need to be removed.
SELECT count(distinct visit_id) FROM central_insights_sandbox.vb_rec_exp_ids_hid WHERE dt = 20200427;
-- Check how many there are
DROP TABLE IF EXISTS vb_exp_multiple_variants;
CREATE TABLE vb_exp_multiple_variants AS
SELECT dt, num_groups, count(DISTINCT visit_id) AS num_visits
FROM (SELECT dt, bbc_hid3, visit_id, count(DISTINCT exp_group) AS num_groups
      FROM central_insights_sandbox.vb_rec_exp_ids_hid
      GROUP BY 1, 2, 3
    ORDER BY num_groups DESC)
GROUP BY 1, 2
ORDER BY 1,2;
--SELECT * FROM vb_exp_multiple_variants;
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- Add helper columns
ALTER TABLE central_insights_sandbox.vb_rec_exp_ids_hid
ADD id_col varchar(400);
UPDATE central_insights_sandbox.vb_rec_exp_ids_hid
SET id_col = dt||bbc_hid3 || visit_id;

-- Identify visits
DROP TABLE IF EXISTS vb_result_multiple_exp_groups;
CREATE TEMP TABLE vb_result_multiple_exp_groups AS
    SELECT CAST(dt || bbc_hid3|| visit_id AS varchar(400)) AS id_col, --create composite id col
           count(DISTINCT exp_group) AS num_groups
      FROM central_insights_sandbox.vb_rec_exp_ids_hid
      GROUP BY 1
        HAVING num_groups >1;
-- Remove visits
DELETE FROM central_insights_sandbox.vb_rec_exp_ids_hid
WHERE id_col IN (SELECT id_col FROM vb_result_multiple_exp_groups);

-- Remove helper column
ALTER TABLE central_insights_sandbox.vb_rec_exp_ids_hid
DROP COLUMN id_col;

/*SELECT platform,
       exp_group,
       count(distinct bbc_hid3)                   as num_hids,
       count(distinct unique_visitor_cookie_id)   as num_uv,
       count(distinct dt || bbc_hid3 || visit_id) AS num_visits
FROM central_insights_sandbox.vb_rec_exp_ids_hid
GROUP BY 1,2;*/

------------------------------------------ Checks - Are any visits lost when adding in age? (test numbers for 020-04-06 to 2020-04-27 )------------------------------------------------
/*-- How many visits are lost?
SELECT count(*) FROM vb_result_multiple_exp_groups WHERE num_groups !=1; -- 45,635 visits are lost by removing those with wo groups
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM central_insights_sandbox.vb_rec_exp_ids); -- 7,833,679
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM central_insights_sandbox.vb_rec_exp_ids_hid); --7,656,493
--How many UV are lost
SELECT COUNT(*) FROM (SELECT DISTINCT dt, unique_visitor_cookie_id FROM central_insights_sandbox.vb_rec_exp_ids); -- 7,420,193
SELECT COUNT(*) FROM (SELECT DISTINCT dt, unique_visitor_cookie_id FROM central_insights_sandbox.vb_rec_exp_ids_hid); --7,270,261

--by platform
SELECT platform, COUNT(*) FROM (SELECT DISTINCT dt, platform, visit_id FROM central_insights_sandbox.vb_rec_exp_ids) GROUP BY platform;
--platform,count
-- web, 1,012,852
-- bigscreen, 6,820,827

SELECT platform, COUNT(*) FROM (SELECT DISTINCT dt, platform, visit_id FROM central_insights_sandbox.vb_rec_exp_ids_hid) GROUP BY platform;
--platform,count
-- web, 989,970
-- bigscreen, 6,666,523

-- How many hids have more than one age range? SHOULD be as close to zero as possible
SELECT COUNT(*)
FROM (SELECT DISTINCT bbc_hid3, count(DISTINCT age_range) AS num_age_ranges
      FROM central_insights_sandbox.vb_rec_exp_ids_hid
      GROUP BY bbc_hid3
      HAVING count(DISTINCT age_range) > 1); --ZERO!!

 */
---------------------------------------------------------------------------------------------------------------------------------------------------



------------------------------------------------------- Impressions - web only--------------------------------------------------------------------------------------------
-- Get all impressions to the each module for this exp group
DROP TABLE IF EXISTS central_insights_sandbox.vb_module_impressions;
CREATE TABLE central_insights_sandbox.vb_module_impressions AS
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
        JOIN central_insights_sandbox.vb_rec_exp_ids_hid b ON a.destination = b.destination AND a.dt = b.dt
    AND a.visit_id = b.visit_id AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id
WHERE a.destination = 'PS_IPLAYER'
  AND a.dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
      AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
  AND a.publisher_impressions = 1
  AND placement = 'iplayer.tv.page'--homepage only
  AND a.metadata ILIKE '%responsive::iplayer%'
  AND b.platform = 'web'
;

-- How many visits were there and how many actually saw the rec-module
/*SELECT count(visit_id) FROM central_insights_sandbox.vb_rec_exp_ids_hid
    WHERE dt = 20200427 and platform = 'web'; -- 202,103
SELECT count(DISTINCT visit_id) FROM central_insights_sandbox.vb_module_impressions
    WHERE dt = 20200427 AND container = 'module-recommendations-recommended-for-you'; -- 26,416
*/

-- Counts - all modules
/*SELECT dt, platform, container, age_range, count(*) AS count_module_views
FROM central_insights_sandbox.vb_module_impressions
GROUP BY dt, platform,container, age_range
;*/

----------------------------------------  Linking the click to content to the episode start ----------------------------------------

-- Need to identify all the clicks to content and link them to the ixpl-start flag.
-- Need all the clicks, not just from homepage, to make sure a click from homepage is not incorrectly linked to (for exmaple) content autoplaying.
-- Need to eliminate clicks from the TLEO because these are a middle step from homepage.

-- For the recommended module we need to know what recommendation group the content was in - this comes in the user_experience field.
-- All standard clicks
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_content_clicks;
CREATE TABLE central_insights_sandbox.vb_exp_content_clicks AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                CASE
                    WHEN a.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
                    ELSE a.container END AS container,
                a.attribute,
                a.placement,
                a.result,
                a.user_experience
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_rec_exp_ids_hid b -- this is to bring in only those visits in our exp group
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE (a.attribute LIKE 'content-item%' OR a.attribute LIKE 'start-watching%' OR a.attribute = 'resume' OR
       a.attribute = 'next-episode' OR a.attribute = 'search-result-episode~click' OR a.attribute = 'page-section-related~select')
  AND a.publisher_clicks = 1
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
AND a.placement NOT ILIKE '%tleo%' -- we need homepage-episode, ignoring any TLEO middle step
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;

--SELECT * FROM central_insights_sandbox.vb_exp_content_clicks ORDER BY dt, visit_id, event_position LIMIT 500;

-- Clicks can come from the autoplay system starting an episode
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_autoplay_clicks;
CREATE TABLE central_insights_sandbox.vb_exp_autoplay_clicks AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                CASE
                    WHEN a.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
                    ELSE a.container END AS container,
                a.attribute,
                a.placement,
                CASE
                    WHEN left(right(a.placement, 13), 8) SIMILAR TO '%[0-9]%'
                        THEN left(right(a.placement, 13), 8) -- if this contains a number then its an ep id, if not make blank
                    ELSE 'none' END AS current_ep_id,
                a.result            AS next_ep_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_rec_exp_ids_hid b -- this is to bring in only those visits in our journey table
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE (a.attribute LIKE '%squeeze-auto-play%' OR a.attribute LIKE '%squeeze-play%' OR a.attribute LIKE '%end-play%' OR
       a.attribute LIKE '%end-auto-play%' OR a.attribute LIKE '%select-play%')
  AND a.publisher_clicks = 1
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;

-- The autoplay on web doesn't currently send any click. It just shows the countdown to autoplay completing as an impression.
-- Include this as a click for now until better tracking is in place
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_autoplay_web_complete;
CREATE TABLE central_insights_sandbox.vb_exp_autoplay_web_complete AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                CASE
                    WHEN a.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
                    ELSE a.container END AS container,
                a.attribute,
                a.placement,
                CASE
                    WHEN left(right(a.placement, 13), 8) SIMILAR TO '%[0-9]%'
                        THEN left(right(a.placement, 13), 8) -- if this contains a number then its an ep id, if not make blank
                    ELSE 'none' END AS current_ep_id,
                a.result            AS next_ep_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_rec_exp_ids_hid  b -- this is to bring in only those visits in our journey table
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE a.attribute LIKE '%onward-journey-panel~complete%'
  AND a.publisher_impressions = 1
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;


-- Deep links into content from off platform. This needs to regex to identify the content pid the link took users too.
-- Not all pids can be identified and not all links go direct to content.
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_deeplinks_temp;
CREATE TABLE central_insights_sandbox.vb_exp_deeplinks_temp AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.url,
                CASE
                    WHEN a.url ILIKE '%/playback%' THEN SUBSTRING(
                            REVERSE(regexp_substr(REVERSE(a.url), '[[:alnum:]]{6}[0-9]{1}[pbwnmlc]{1}/')), 2,
                            8) -- Need the final instance of the phrase'/playback' to get the episode ID so reverse url so that it's now first.
                    ELSE 'unknown' END                                                                   AS click_result,
                row_number()
                over (PARTITION BY a.dt,a.unique_visitor_cookie_id,a.visit_id ORDER BY a.event_position) AS row_count
FROM s3_audience.events a
         JOIN central_insights_sandbox.vb_rec_exp_ids_hid  b -- this is to bring in only those visits in our journey table
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE a.destination = b.destination
  AND a.url LIKE '%deeplink%'
  AND a.url IS NOT NULL
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;

-- Take only the first deep link instance
-- Later this will be joined to VMB to ensure link takes directly to a content page.
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_deeplinks;
CREATE TABLE central_insights_sandbox.vb_exp_deeplinks AS
SELECT *
FROM central_insights_sandbox.vb_exp_deeplinks_temp
WHERE row_count = 1;

------------- Join all the different types of click to content into one table -------------
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_all_content_clicks;
-- Regular clicks
CREATE TABLE central_insights_sandbox.vb_exp_all_content_clicks
AS
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       result AS click_destination_id,
       user_experience AS think_group -- this will only apply to content from the homepage rec-module. Most will be NULL.
FROM central_insights_sandbox.vb_exp_content_clicks;

-- Autoplay
INSERT INTO central_insights_sandbox.vb_exp_all_content_clicks
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       next_ep_id AS click_destination_id
FROM central_insights_sandbox.vb_exp_autoplay_clicks;

SELECT * FROM central_insights_sandbox.vb_exp_all_content_clicks WHERE attribute ILIKE '%squeeze-auto-play%' LIMIT 10;
-- Web autoplay
INSERT INTO central_insights_sandbox.vb_exp_all_content_clicks
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       next_ep_id AS click_destination_id
FROM central_insights_sandbox.vb_exp_autoplay_web_complete;

-- Deeplinks
INSERT INTO central_insights_sandbox.vb_exp_all_content_clicks
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       CAST('deeplink' AS varchar) AS container,
       CAST('deeplink' AS varchar) AS attribute,
       CAST('deeplink' AS varchar) AS placement,
       click_result                AS click_destination_id
FROM central_insights_sandbox.vb_exp_deeplinks;


--SELECT * FROM central_insights_sandbox.vb_exp_all_content_clicks ORDER BY visit_id, event_position LIMIT 100;


-------------------------------------- Select all the ixpl-start impressions and link them back to the click to content -----------------------------------------------------------------

-- For every dt/user/visit combination find all the ixpl start labels from the user group
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_play_starts;
CREATE TABLE central_insights_sandbox.vb_exp_play_starts AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.container,
                a.attribute,
                a.placement,
                a.result AS content_id,
                CAST(NULL AS varchar(400)) AS think_group,
                ISNULL(c.series_id,'unknown') AS series_id,
                ISNULL(c.brand_id, 'unknown') AS brand_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_rec_exp_ids_hid  b
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.dt = b.dt AND a.visit_id = b.visit_id
LEFT JOIN central_insights_sandbox.vb_vmb_temp c ON a.result = c.episode_id
WHERE a.publisher_impressions = 1
  AND a.attribute = 'iplxp-ep-started'
  AND a.destination = 'PS_IPLAYER'
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;

--SELECT visit_id, COUNT(*) FROM central_insights_sandbox.vb_exp_play_starts GROUP BY visit_id; --70,228 - seems high
--SELECT * FROM central_insights_sandbox.vb_exp_play_starts WHERE visit_id = 18960542 ORDER BY visit_id, event_position;

-- Join clicks and starts into one master table. (some clicks will not be to a content page i.e homepage > TLEO and will be dealt with later)
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_clicks_and_starts_temp;
-- Add in start events
CREATE TABLE central_insights_sandbox.vb_exp_clicks_and_starts_temp AS
SELECT *
FROM central_insights_sandbox.vb_exp_play_starts;

-- Add in click events
INSERT INTO central_insights_sandbox.vb_exp_clicks_and_starts_temp
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       click_destination_id AS content_id,
       think_group
FROM central_insights_sandbox.vb_exp_all_content_clicks;

-- Add in row number for each visit
-- This is used to match a content click to a start if the click carried no ID (i.e with categories or channels pages)
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_clicks_and_starts;
CREATE TABLE central_insights_sandbox.vb_exp_clicks_and_starts AS
SELECT *, row_number() over (PARTITION BY dt,unique_visitor_cookie_id,bbc_hid3, visit_id ORDER BY event_position)
FROM central_insights_sandbox.vb_exp_clicks_and_starts_temp
ORDER BY dt, unique_visitor_cookie_id, bbc_hid3, visit_id, event_position;

--SELECT * FROM central_insights_sandbox.vb_exp_clicks_and_starts  WHERE think_group IS NOT NULL LIMIT 5;
-- Join the table back on itself to match the content click to the ixpl start by the content_id.
-- For categories and channels the click ID is often unknown so need to create one master table so the click event before ixpl start can be taken in these cases
-- If that's ever fixed then can simply join play starts with clicks
-- The clicks and start flags are split into two temp tables for ease of code. Can't just join the two original tables because we need the row count for when the content_id is unknown.
DROP TABLE IF EXISTS vb_temp_starts;
DROP TABLE IF EXISTS vb_temp_clicks;
CREATE TEMP TABLE vb_temp_starts AS SELECT * FROM central_insights_sandbox.vb_exp_clicks_and_starts WHERE attribute = 'iplxp-ep-started';
CREATE TEMP TABLE vb_temp_clicks AS SELECT * FROM central_insights_sandbox.vb_exp_clicks_and_starts WHERE attribute != 'iplxp-ep-started';

--SELECT * FROM central_insights_sandbox.vb_exp_clicks_and_starts WHERE visit_id = 14308991 OR visit_id = 21656571 OR visit_id = 23192602;

DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_clicks_linked_starts_temp;
CREATE TABLE central_insights_sandbox.vb_exp_clicks_linked_starts_temp AS
SELECT a.dt,
       a.unique_visitor_cookie_id,
       a.bbc_hid3,
       a.visit_id,
       a.think_group                        AS click_think_group,
       a.event_position                     AS click_event_position,
       a.container                          AS click_container,
       a.attribute                          AS click_attibute,
       a.placement                          AS click_placement,
       a.content_id                         AS click_id,
       b.container                          AS content_container,
       ISNULL(b.attribute, 'no-start-flag') AS content_attribute,
       b.placement                          AS content_placement,
       b.content_id                         AS content_id,
       b.event_position                     AS content_start_event_position,
       CASE
           WHEN b.event_position IS NOT NULL THEN CAST(b.event_position - a.event_position AS integer)
           ELSE 0 END                       AS content_start_diff
FROM vb_temp_clicks a
         LEFT JOIN vb_temp_starts b
                   ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                      a.visit_id = b.visit_id AND CASE
                                                      WHEN a.content_id != 'unknown' AND a.content_id = b.content_id
                                                          THEN a.content_id = b.content_id -- Check the content IDs match if possible
                                                      WHEN a.content_id != 'unknown' AND
                                                           a.content_id != b.content_id AND a.content_id = b.series_id
                                                          THEN a.content_id = b.series_id -- see if the click's content id is actually a series
                                                      WHEN a.content_id != 'unknown' AND
                                                           a.content_id != b.content_id AND
                                                           a.content_id != b.series_id AND a.content_id = b.brand_id
                                                          THEN a.content_id = b.brand_id -- see if the click's content id is actually a series
                                                      WHEN a.content_id = 'unknown'
                                                          THEN a.row_number = b.row_number - 1 -- Click is row above start - if you can't check IDs or master brands, just link with row above (click is one above start)
                          END
WHERE content_start_diff >= 0 -- For the null cases with no matching start flag the value given = 0.
--AND (a.visit_id = 14308991 OR a.visit_id = 21656571 OR a.visit_id = 23192602);
ORDER BY a.visit_id, a.event_position
;


-- Need to deduplicate as multiple clicks to one piece of content could only result one ixpl-start flag
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_clicks_linked_starts_valid_temp;
CREATE TABLE central_insights_sandbox.vb_exp_clicks_linked_starts_valid_temp AS
SELECT *,
       CASE
           WHEN content_attribute = 'iplxp-ep-started' THEN row_number()
                                                            over (PARTITION BY dt,unique_visitor_cookie_id,bbc_hid3, visit_id,click_event_position ORDER BY content_start_diff)
           ELSE 1 END AS duplicate_count
FROM central_insights_sandbox.vb_exp_clicks_linked_starts_temp
ORDER BY dt, bbc_hid3, visit_id, content_start_event_position;


-- Remove duplicates
-- Values with no start flag need to be kept so they're given duplicate_count = 1
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_clicks_linked_starts_valid;
CREATE TABLE central_insights_sandbox.vb_exp_clicks_linked_starts_valid AS
SELECT *
FROM central_insights_sandbox.vb_exp_clicks_linked_starts_valid_temp
WHERE duplicate_count = 1;

--SELECT * FROM central_insights_sandbox.vb_exp_clicks_linked_starts_valid  WHERE (visit_id = 2102182 OR visit_id = 2932254);

-- The above ensures each start is only joined with one click, but there may be multiple clicks to the same content, with only one resulting in a start (start closest to click is chosen)
-- These need to be joined back in as clicks that had no start
INSERT INTO central_insights_sandbox.vb_exp_clicks_linked_starts_valid
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       think_group    AS click_think_group,
       event_position AS click_event_position,
       container      AS click_container,
       attribute      AS click_attribute,
       placement      AS click_placement,
       content_id     AS click_episode_id
FROM (SELECT a.*, b.visit_id as missing_flag
      FROM vb_temp_clicks a
               LEFT JOIN central_insights_sandbox.vb_exp_clicks_linked_starts_valid b
                         ON a.dt = b.dt AND a.bbc_hid3 = b.bbc_hid3 AND a.visit_id = b.visit_id AND
                            a.event_position = b.click_event_position)
WHERE missing_flag IS NULL;


-- Define value if there's no start
UPDATE central_insights_sandbox.vb_exp_clicks_linked_starts_valid
SET content_attribute = (CASE
                             WHEN content_attribute IS NULL THEN 'no-start-flag'
                             ELSE content_attribute END);
SELECT * FROM  central_insights_sandbox.vb_exp_clicks_linked_starts_valid LIMIT 100;
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_valid_starts;
CREATE TABLE central_insights_sandbox.vb_exp_valid_starts AS
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       click_think_group,
       click_attibute,
       click_container,
       click_placement,
       click_id,
       click_event_position,
       content_attribute,
       content_placement,
       content_id,
       content_start_event_position
FROM central_insights_sandbox.vb_exp_clicks_linked_starts_valid;

--SELECT * FROM central_insights_sandbox.vb_exp_valid_starts limit 5;

/*SELECT click_container, content_attribute, count(visit_id) AS num_clicks
FROM central_insights_sandbox.vb_exp_valid_starts
    WHERE click_placement = 'iplayer.tv.page' --homepage
    GROUP BY 1,2;*/



---------------------------------------------------  Add in watched flags and validate them -------------------------------------------------

-- For every dt/user/visit combination find all the ixpl watched labels
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_play_watched;
CREATE TABLE central_insights_sandbox.vb_exp_play_watched AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.container,
                a.attribute,
                a.placement,
                a.result AS content_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_rec_exp_ids_hid b
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.dt = b.dt AND a.visit_id = b.visit_id
WHERE a.publisher_impressions = 1
  AND a.attribute = 'iplxp-ep-watched'
  AND a.destination = 'PS_IPLAYER'
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;


-- Join the watch events to the validated start events, ensuring the same content_id
-- Deduplcate to make sure one watched flag isn't joined to two start flag
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_starts_and_watched;
CREATE TABLE central_insights_sandbox.vb_exp_starts_and_watched AS
SELECT a.*,
       ISNULL(b.attribute, 'no-watched-flag') AS content_attribute2,
       b.event_position                       AS content_watched_event_position,
       b.content_id                           AS watched_content_id,
       CASE
           WHEN b.event_position Is NOT NULL THEN CAST(b.event_position - a.content_start_event_position AS integer)
           ELSE 0 END                         AS start_watched_diff,
       CASE
           WHEN content_attribute2 = 'iplxp-ep-watched' THEN row_number()
                                                             over (PARTITION BY a.dt,a.unique_visitor_cookie_id,a.bbc_hid3, a.visit_id,a.content_start_event_position ORDER BY start_watched_diff)
           ELSE 1 END                         AS duplicate_count
FROM central_insights_sandbox.vb_exp_valid_starts a
         LEFT JOIN central_insights_sandbox.vb_exp_play_watched b
                   ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.dt = b.dt AND
                      a.visit_id = b.visit_id AND a.content_id = b.content_id
WHERE start_watched_diff >= 0
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.click_event_position;


-- Prevents any watched flag from being joined to multiple starts
-- If more than one start occurs for an ID this removes the one not matched to the watched. So those will need to be added back in to ensure one start without a watched and one with.
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_valid_watched;
CREATE TABLE central_insights_sandbox.vb_exp_valid_watched AS
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       click_think_group,
       click_event_position,
       click_container,
       click_placement,
       content_placement,
       content_id,
       content_start_event_position,
       content_watched_event_position,
       content_attribute  AS start_flag,
       content_attribute2 AS watched_flag
FROM central_insights_sandbox.vb_exp_starts_and_watched
WHERE duplicate_count = 1;


INSERT INTO central_insights_sandbox.vb_exp_valid_watched
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       click_think_group,
       click_event_position,
       click_container,
       click_placement,
       content_placement,
       content_id,
       content_start_event_position,
       content_watched_event_position
FROM (
         SELECT a.*,b.content_watched_event_position, b.visit_id as missing_flag
         FROM central_insights_sandbox.vb_exp_valid_starts a
                  LEFT JOIN central_insights_sandbox.vb_exp_valid_watched b
                            ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                               a.visit_id = b.visit_id AND
                               a.click_event_position = b.click_event_position
     )
WHERE missing_flag ISNULL;


UPDATE central_insights_sandbox.vb_exp_valid_watched
SET start_flag = (CASE
                      WHEN start_flag IS NULL THEN 'no-start-flag'
                      ELSE start_flag END);
UPDATE central_insights_sandbox.vb_exp_valid_watched
SET watched_flag = (CASE
                        WHEN watched_flag IS NULL THEN 'no-watched-flag'
                        ELSE watched_flag END);

DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_valid_watched_enriched;
CREATE TABLE central_insights_sandbox.vb_exp_valid_watched_enriched AS
SELECT a.dt,
       a.unique_visitor_cookie_id,
       a.bbc_hid3,
       a.visit_id,
       a.click_think_group,
       a.click_event_position,
       a.click_container,
       a.click_placement,
       a.content_placement,
       a.content_id,
       a.content_start_event_position,
       a.content_watched_event_position,
       CASE WHEN a.start_flag = 'iplxp-ep-started' THEN 1
           ELSE 0 END as start_flag,
       CASE WHEN a.watched_flag = 'iplxp-ep-watched' THEN 1
           ELSE 0 END as watched_flag,
       b.platform,
       b.exp_group,
       --b.exp_subgroup,
       b.age_range
FROM central_insights_sandbox.vb_exp_valid_watched a
         LEFT JOIN central_insights_sandbox.vb_rec_exp_ids_hid b
                   ON a.dt = b.dt AND a.bbc_hid3 = b.bbc_hid3 AND a.visit_id = b.visit_id
;

----- Create final table so can push additional weeks of data into it
/*CREATE TABLE central_insights_sandbox.vb_rec_exp_final AS
    SELECT * FROM central_insights_sandbox.vb_exp_valid_watched_enriched;*/

SELECT * FROM central_insights_sandbox.vb_rec_exp_final LIMIT 10;

INSERT INTO central_insights_sandbox.vb_rec_exp_final
    SELECT * FROM central_insights_sandbox.vb_exp_valid_watched_enriched;



---- Look at results
SELECT platform, exp_group, count(distinct unique_visitor_cookie_id) AS num_users, count(distinct visit_id) AS num_visits
FROM central_insights_sandbox.vb_exp_valid_watched_enriched
--FROM central_insights_sandbox.vb_rec_exp_ids_hid
GROUP BY 1,2;

--SELECT * FROM central_insights_sandbox.vb_exp_valid_watched_enriched LIMIT 100;

SELECT *
FROM (SELECT
             exp_group,
             count(distinct bbc_hid3)                   as num_hids,
             count(distinct unique_visitor_cookie_id)   as num_uv,
             count(distinct dt || bbc_hid3 || visit_id) AS num_visits
      FROM central_insights_sandbox.vb_rec_exp_ids_hid
      GROUP BY 1) a
         JOIN (SELECT
                      exp_group,
                      sum(start_flag)   AS num_starts,
                      sum(watched_flag) as num_watched,
                      count(visit_id)   AS num_clicks_to_module
               FROM central_insights_sandbox.vb_exp_valid_watched_enriched
               WHERE click_placement = 'iplayer.tv.page' --homepage
                 AND click_container = 'module-recommendations-recommended-for-you'
               GROUP BY 1) b ON a.exp_group = b.exp_group
ORDER BY a.exp_group;


------------------------------------------------  END  --------------------------------------------------------------------------------

-- Data for analysis
-- Check dates
SELECT * FROM central_insights_sandbox.vb_homepage_rec_date_range;
-- How many hids?
SELECT platform,
       exp_group,
       age_range,
       count(DISTINCT bbc_hid3) AS num_signed_in_users
FROM central_insights_sandbox.vb_rec_exp_ids_hid
GROUP BY 1, 2,3
ORDER BY 1,2,3;

-- How many visits?
SELECT platform,
       exp_group,
       age_range,
       count(visit_id) AS num_visits
FROM central_insights_sandbox.vb_rec_exp_ids_hid
GROUP BY 1, 2,3
ORDER BY 1,2,3;

--num starts total
SELECT --platform,
       exp_group,
       --age_range,
       sum(start_flag)   as num_starts,
       sum(watched_flag) as num_watched
FROM central_insights_sandbox.vb_exp_valid_watched_enriched
WHERE click_container = 'module-recommendations-recommended-for-you'
AND click_placement = 'iplayer.tv.page' --homepage
GROUP BY 1--, 2,3
ORDER BY 1;--,2,3;

-- number of module impressions
SELECT a.platform,
       b.exp_group,
       a.age_range,
       count(a.visit_id) AS num_visits_saw_module
FROM central_insights_sandbox.vb_module_impressions a
JOIN central_insights_sandbox.vb_rec_exp_ids_hid b  on a.dt = b.dt AND a.bbc_hid3 = b.bbc_hid3 and a.visit_id = b.visit_id
WHERE a.container = 'module-recommendations-recommended-for-you'
GROUP BY 1, 2,3
ORDER BY 1,2,3;

-- Number of module clicks
SELECT platform,
       exp_group,
       age_range,
       count(visit_id) AS num_clicks
FROM central_insights_sandbox.vb_exp_valid_watched_enriched
WHERE click_container = 'module-recommendations-recommended-for-you'
GROUP BY 1, 2,3
ORDER BY 1,2,3;





-- Temp table giving number of starts and watched for each hid
CREATE TEMP TABLE vb_rec_exp_module_clicks AS
SELECT platform,
       exp_group,
       age_range,
       bbc_hid3,
       sum(start_flag)   as num_starts,
       sum(watched_flag) as num_watched
FROM central_insights_sandbox.vb_exp_valid_watched_enriched
WHERE click_container = 'module-recommendations-recommended-for-you'
GROUP BY 1, 2, 3,4;

CREATE TEMP TABLE vb_rec_exp_results AS
SELECT DISTINCT a.platform,
                a.exp_group,
                a.age_range,
                a.bbc_hid3,
                ISNULL(b.num_starts, 0)  as num_starts,
                ISNULL(b.num_watched, 0) AS num_watched
FROM central_insights_sandbox.vb_rec_exp_ids_hid a
         LEFT JOIN vb_rec_exp_module_clicks b
                   on a.bbc_hid3 = b.bbc_hid3 AND a.platform = b.platform AND a.exp_group = b.exp_group
;
SELECT * FROM vb_rec_exp_results; --pull out all results and manipulate in R.



SELECT platform, exp_group, count(DISTINCT bbc_hid3)
FROM vb_rec_exp_results
GROUP BY 1,2;


SELECT platform, exp_group, click_think_group, sum(start_flag) as num_starts, sum(watched_flag) as num_watched
FROM central_insights_sandbox.vb_exp_valid_watched_enriched
WHERE click_think_group IS NOT NULL
GROUP By 1,2,3;

SELECT DISTINCT dt FROM central_insights_sandbox.vb_exp_valid_watched_enriched;