
--- Exp v1
SELECT * FROM central_insights_sandbox.vb_rec_exp_final_plxp_irex1_model1_1;
SELECT * FROM vb_exp_hids_v1;
SELECT * FROM vb_exp_impr_v1;


-- EXP v2
SELECT * FROM vb_exp_hids_v2;
SELECT * FROM central_insights_sandbox.vb_rec_exp_final_iplxp_irex_model1_2 LIMIT 10;
SELECT * FROM vb_exp_impr_v2;

CREATE TABLE vb_exp_impr_v2 AS SELECT * FROM central_insights_sandbox.vb_module_impressions ;

-- How many clicks on each module
SELECT dt,
       exp_group,
       click_container,
       sum(start_flag)   as num_starts,
       sum(watched_flag) as num_watched,
       count(visit_id)   AS num_clicks
FROM central_insights_sandbox.vb_rec_exp_final_iplxp_irex_model1_2
WHERE (click_container = 'module-recommendations-recommended-for-you' OR
    OR click_container = 'module-editorial-featured')
  AND click_placement = 'iplayer.tv.page'
GROUP BY 1, 2,3
ORDER BY 1, 2,3;


-- Impressions
SELECT a.dt, a.exp_group, b.container, count(DISTINCT a.visit_id) as num_visits
FROM vb_exp_hids_v2 a
         LEFT JOIN vb_exp_impr_v2 b
                   ON a.dt = b.dt and a.visit_id = b.visit_id
WHERE b.container = 'module-watching-continue-watching'
   OR b.container = 'module-recommendations-recommended-for-you'
GROUP BY 1, 2,3;


-- Frequency
SELECT a.dt,
       a.exp_group,
       case when b.frequency_band is null then 'new' else b.frequency_band end   as frequency_band,
       central_insights_sandbox.udf_dataforce_frequency_groups(b.frequency_band) as frequency_group_aggregated,
       COUNT(a.visit_id)
FROM vb_exp_hids_v1 a
         LEFT JOIN iplayer_sandbox.iplayer_weekly_frequency_calculations b
                   ON (a.bbc_hid3 = b.bbc_hid3 and
                       trunc(date_trunc('week', cast(a.dt as date))) = b.date_of_segmentation)
GROUP BY 1,2,3,4;




/*v1 with a blend of popular

  glasto and sport - for new people they'd get nothing shown in the exp group.
  1. Have a look at the impressions - did people see a module?
  2. Frequency groups - who was new/dormant.

  If you create an account then watch twice in a week are you still a new users?
  run again with control v1, and v2
  turn off cold.

 */

 /*
  in autoplay
  what makes the best rec?
  What did people watch directly after they finished one episode within a session?
  How did those next episodes compare to the previous one.
  Session time - how long did people watch for typically?

  Of the people who discovered something new (new TLEO) how did their session length vary.
  How similar is the new TLEO.
  time of day?
  /*


  */

