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
                   OR metadata ILIKE '%responsive::iplayer%')) b
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

SELECT * FROM central_insights_sandbox.vb_rec_exp_ids LIMIT 100;


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

------------------------------------------ Checks - Are any visits lost when adding in age? (test numbers for 2020-04-06)-------------------------------------------------
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM central_insights_sandbox.vb_rec_exp_ids); -- 16,797
SELECT COUNT(*) FROM (SELECT DISTINCT dt, visit_id FROM central_insights_sandbox.vb_rec_exp_ids_hid); --16,446
--How many UV are lost
SELECT COUNT(*) FROM (SELECT DISTINCT dt, unique_visitor_cookie_id FROM central_insights_sandbox.vb_rec_exp_ids); -- 16,465
SELECT COUNT(*) FROM (SELECT DISTINCT dt, unique_visitor_cookie_id FROM central_insights_sandbox.vb_rec_exp_ids_hid); --16,127

--by platform
SELECT platform, COUNT(*) FROM (SELECT DISTINCT dt, platform, visit_id FROM central_insights_sandbox.vb_rec_exp_ids) GROUP BY platform;
--platform,count
-- web, 9,598
-- bigscreen, 7,199

SELECT platform, COUNT(*) FROM (SELECT DISTINCT dt, platform, visit_id FROM central_insights_sandbox.vb_rec_exp_ids_hid) GROUP BY platform;
--platform,count
-- web, 9,397
-- bigscreen, 7,055

-- How many hids have more than one age range? SHOULD be as close to zero as possible
SELECT COUNT(*)
FROM (SELECT DISTINCT bbc_hid3, count(DISTINCT age_range) AS num_age_ranges
      FROM central_insights_sandbox.vb_rec_exp_ids_hid
      GROUP BY bbc_hid3
      HAVING count(DISTINCT age_range) > 1); --ZERO!!
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
  AND b.platform = 'web'
;

-- Counts - all modules
SELECT dt, platform, container, age_range, count(*) AS count_module_views
FROM central_insights_sandbox.vb_module_impressions
GROUP BY dt, platform,container, age_range
;

----------------------------------------  Linking the click to content to the episode start ----------------------------------------

-- Need to identify all the clicks to content and link them to the ixpl-start flag.
-- Need all the clicks, not just from homepage, to make sure a click from homepage is not incorrectly linked to (for exmaple) content autoplaying.
-- Need to eliminate clicks from the TLEO because these are a middle step from homepage.

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
                a.result
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
       result AS click_destination_id
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
       click_destination_id AS content_id
FROM central_insights_sandbox.vb_exp_all_content_clicks;

-- Add in row number for each visit
-- This is used to match a content click to a start if the click carried no ID (i.e with categories or channels pages)
DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_clicks_and_starts;
CREATE TABLE central_insights_sandbox.vb_exp_clicks_and_starts AS
SELECT *, row_number() over (PARTITION BY dt,unique_visitor_cookie_id,bbc_hid3, visit_id ORDER BY event_position)
FROM central_insights_sandbox.vb_exp_clicks_and_starts_temp
ORDER BY dt, unique_visitor_cookie_id, bbc_hid3, visit_id, event_position;


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
       a.event_position                                                                                            AS click_event_position,
       a.container                                                                                                 AS click_container,
       a.attribute                                                                                                 AS click_attibute,
       a.placement                                                                                                 AS click_placement,
       a.content_id                                                                                                AS click_id,
       b.container                                                                                                 AS content_container,
       ISNULL(b.attribute, 'no-start-flag')                                                                        AS content_attribute,
       b.placement                                                                                                 AS content_placement,
       b.content_id                                                                                                AS content_id,
       b.event_position                                                                                            AS content_start_event_position,
       CASE
           WHEN b.event_position IS NOT NULL THEN CAST(b.event_position - a.event_position AS integer)
           ELSE 0 END                                                                                              AS content_start_diff
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
       event_position                       AS click_event_position,
       container                            AS click_container,
       attribute                            AS click_attribute,
       placement                            AS click_placement,
       content_id                           AS click_episode_id
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

DROP TABLE IF EXISTS central_insights_sandbox.vb_exp_valid_starts;
CREATE TABLE central_insights_sandbox.vb_exp_valid_starts AS
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
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

SELECT click_container, content_attribute, count(visit_id) AS num_clicks
FROM central_insights_sandbox.vb_exp_valid_starts
    WHERE click_placement = 'iplayer.tv.page' --homepage
    GROUP BY 1,2;
---------------------------------------------------------------------------------------------------------------------------------





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

