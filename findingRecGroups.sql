SELECT * FROM central_insights_sandbox.vb_rec_exp_ids_hid LIMIT 100;
--Questions:
-- Finding think groups - If they're on web they can see item 1 & 2 easily to give impressions, but for tv they'll have to click.
-- What % of users have a think group identifiable?
-- What think group were the irex group before the experiment?
-- need to find what rec group each click was using the position
-- need to find out what rec group those people were before

-- How many in each group?
SELECT exp_group, count(visit_id)
FROM central_insights_sandbox.vb_rec_exp_ids_hid
GROUP BY 1;


-- What % of user's have a think group identifiable.
-- 1. For each hid select the distinct user experiences that are think or blank.
DROP TABLE vb_distinct_user_experience;
CREATE TEMP TABLE vb_distinct_user_experience AS
SELECT DISTINCT bbc_hid3, exp_group, CAST(NULL as varchar(400)) AS user_experience
FROM central_insights_sandbox.vb_rec_exp_ids_hid
WHERE exp_group != 'variation_2';

INSERT INTO vb_distinct_user_experience
SELECT DISTINCT b.bbc_hid3,
                b.exp_group,
                a.user_experience
FROM central_insights_sandbox.vb_rec_exp_ids_hid b
    LEFT JOIN s3_audience.publisher a
                    ON a.dt = b.dt and a.visit_id = b.visit_id AND
                       a.unique_visitor_cookie_id = b.unique_visitor_cookie_id
WHERE a.dt between (SELECT min_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
    AND (SELECT max_date FROM central_insights_sandbox.vb_homepage_rec_date_range)
  AND b.exp_group != 'variation_2'
   AND a.user_experience ILIKE 'REC=think%' AND a.user_experience ILIKE '%homepg%'
ORDER BY b.bbc_hid3
;

-- This gives  2,867,789 users total with only  324,259 having a think group identifiable (~11%)
SELECT user_experience, COUNT(DISTINCT bbc_hid3) as num_hids FROM vb_distinct_user_experience
GROUP BY 1;

SELECT COUNT(DISTINCT bbc_hid3) FROM central_insights_sandbox.vb_rec_exp_ids_hid WHERE exp_group != 'variation_2'; --2,867,789
SELECT COUNT(DISTINCT bbc_hid3) FROM vb_distinct_user_experience; --2,867,789 2,865,886

-- 2. Select only the ones with noth



