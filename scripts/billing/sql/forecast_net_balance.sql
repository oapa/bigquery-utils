/*
Query returns the forecasted future balance for the next month given
historical usage trends
*/

SELECT
  month,
  balance,
  future_balance
FROM (
  SELECT
    FORMAT_TIMESTAMP('%Y%m', usage_end_time) AS month,
    SUM(cost) + SUM((SELECT SUM(amount) FROM UNNEST(credits))) AS balance,
    NULL AS future_balance
  FROM `data-analytics-pocs.public.billing_dashboard_export`
  WHERE
    FORMAT_TIMESTAMP('%Y%m', usage_end_time) 
      >= FORMAT_DATE('%Y%m', DATE_ADD(CURRENT_DATE(), INTERVAL -3 MONTH))
    AND FORMAT_TIMESTAMP('%Y%m', usage_end_time) 
      != FORMAT_TIMESTAMP('%Y%m', CURRENT_TIMESTAMP())
  GROUP BY month
  ORDER BY month
)
UNION ALL (
  SELECT
    FORMAT_TIMESTAMP('%Y%m', CURRENT_TIMESTAMP()) AS month,
    NULL AS balance,
    SLOPE * (EXTRACT(YEAR FROM CURRENT_TIMESTAMP()) * 12
      + EXTRACT(MONTH FROM CURRENT_TIMESTAMP())) + INTERCEPT AS future_balance
  FROM (
    SELECT 
      SLOPE,
      (SUM_OF_Y - SLOPE * SUM_OF_X) / N AS INTERCEPT,
      CORRELATION
    FROM (
      SELECT 
        N,
        SUM_OF_X,
        SUM_OF_Y,
        CORRELATION * STDDEV_OF_Y / STDDEV_OF_X AS SLOPE,
        CORRELATION
      FROM (
        SELECT 
          COUNT(*) AS N,
          SUM(X) AS SUM_OF_X,
          SUM(Y) AS SUM_OF_Y,
          STDDEV_POP(X) AS STDDEV_OF_X,
          STDDEV_POP(Y) AS STDDEV_OF_Y,
          CORR(X,Y) AS CORRELATION
        FROM (
          SELECT
            EXTRACT(YEAR FROM usage_end_time) * 12
              + EXTRACT(MONTH FROM usage_end_time) AS X,
            SUM(cost) + SUM((SELECT SUM(amount) FROM UNNEST(credits))) AS Y
          FROM `data-analytics-pocs.public.billing_dashboard_export`
          WHERE
            FORMAT_TIMESTAMP('%Y%m', usage_end_time) 
              >= FORMAT_DATE('%Y%m', DATE_ADD(CURRENT_DATE(), INTERVAL -3 MONTH))
          GROUP BY X
          ORDER BY X
        )
        WHERE 
          X IS NOT NULL
          AND Y IS NOT NULL
      )
    )
  )
)
UNION ALL (
  SELECT
    FORMAT_DATE('%Y%m', DATE_ADD(CURRENT_DATE(), INTERVAL 1 MONTH)) AS month,
    NULL AS balance,
    SLOPE * (EXTRACT(YEAR FROM DATE_ADD(CURRENT_DATE(), INTERVAL 1 MONTH)) * 12
      + EXTRACT(MONTH FROM DATE_ADD(CURRENT_DATE(), INTERVAL 1 MONTH)))
      + INTERCEPT AS future_balance
  FROM (
    SELECT 
      SLOPE,
      (SUM_OF_Y - SLOPE * SUM_OF_X) / N AS INTERCEPT,
      CORRELATION
    FROM (
      SELECT 
        N,
        SUM_OF_X,
        SUM_OF_Y,
        CORRELATION * STDDEV_OF_Y / STDDEV_OF_X AS SLOPE,
        CORRELATION
      FROM (
        SELECT 
          COUNT(*) AS N,
          SUM(X) AS SUM_OF_X,
          SUM(Y) AS SUM_OF_Y,
          STDDEV_POP(X) AS STDDEV_OF_X,
          STDDEV_POP(Y) AS STDDEV_OF_Y,
          CORR(X,Y) AS CORRELATION
        FROM (
          SELECT
            EXTRACT(YEAR FROM usage_end_time) * 12
              + EXTRACT(MONTH FROM usage_end_time) AS X,
            SUM(cost) + SUM((SELECT SUM(amount) FROM UNNEST(credits))) AS Y
          FROM `data-analytics-pocs.public.billing_dashboard_export`
          WHERE
            FORMAT_TIMESTAMP('%Y%m', usage_end_time) 
              >= FORMAT_DATE('%Y%m', DATE_ADD(CURRENT_DATE(), INTERVAL -3 MONTH))
          GROUP BY X
          ORDER BY X
        )
        WHERE X IS NOT NULL AND
              Y IS NOT NULL
      )
    )
  )
)
ORDER BY month
