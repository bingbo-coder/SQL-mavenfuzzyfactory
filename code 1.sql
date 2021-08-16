-- Data before April 04 2014
-- from 6th January, introduction of the second product 
-- Conversion funnel from each product page to conversion
-- and we want also the clickthrough rate 

-- 1. Select all pageview of the relevant sessions
DROP TABLE IF EXISTS session_seen_product_page;
CREATE TEMPORARY TABLE session_seen_product_page
SELECT
    website_session_id,
	website_pageview_id,
    pageview_url AS product_page_seen
FROM website_pageviews
WHERE created_at BETWEEN '2013-02-01' AND '2013-04-10'
	AND pageview_url IN ('/the-original-mr-fuzzy','/the-forever-love-bear');
    
SELECT * FROM session_seen_product_page;

-- 2. Look the DISTINCT pageview after product page 
SELECT DISTINCT 
	website_pageviews.pageview_url
FROM session_seen_product_page
	LEFT JOIN website_pageviews	
		ON website_pageviews.website_session_id = session_seen_product_page.website_session_id
        AND website_pageviews.website_pageview_id > session_seen_product_page.website_pageview_id;

-- after the product page : cart, shiipping, billing-2, thank-you-fro-your-order

-- 3. create a flag of the page afterproduct page and order it cronologically 
SELECT 
	session_seen_product_page.website_session_id,
	CASE
		WHEN session_seen_product_page.product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
		WHEN session_seen_product_page.product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
		ELSE 'ERROR'
	END AS product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing2_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS order_page
FROM session_seen_product_page
	LEFT JOIN website_pageviews	
		ON website_pageviews.website_session_id = session_seen_product_page.website_session_id
        AND website_pageviews.website_pageview_id > session_seen_product_page.website_pageview_id
ORDER BY 
	session_seen_product_page.website_session_id,
    website_pageviews.created_at;

-- 4. Group by the sessions and take the step of the session in the flag
DROP TABLE IF EXISTS session_product_page_next_page_flag;
CREATE TEMPORARY TABLE session_product_page_next_page_flag
SELECT 
	website_session_id,
	product_page_seen,
    MAX(cart_page) AS cart_page,
    MAX(shipping_page) AS shipping_page,
    MAX(billing2_page) AS billing2_page,
    MAX(order_page) AS order_page
FROM (
SELECT 
	session_seen_product_page.website_session_id,
	CASE
		WHEN session_seen_product_page.product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
		WHEN session_seen_product_page.product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
		ELSE 'ERROR'
	END AS product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing2_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS order_page
FROM session_seen_product_page
	LEFT JOIN website_pageviews	
		ON website_pageviews.website_session_id = session_seen_product_page.website_session_id
        AND website_pageviews.website_pageview_id > session_seen_product_page.website_pageview_id
ORDER BY 
	session_seen_product_page.website_session_id,
    website_pageviews.created_at
) AS next_product_page_flag
GROUP BY website_session_id 
;

SELECT * FROM session_product_page_next_page_flag;

-- 5. final : take the sum of the session and for the next page session 
DROP TABLE IF EXISTS product_funnel_session;
CREATE TEMPORARY TABLE product_funnel_session
SELECT 
    product_page_seen,
	COUNT(DISTINCT website_session_id) AS product_page_sessions,
    SUM(cart_page) AS cart_page_sessions,
    SUM(shipping_page) AS shipping_page_sessions,
    SUM(billing2_page) AS billing2_page_sessions,
    SUM(order_page) AS order_page_sessions
FROM session_product_page_next_page_flag
GROUP BY product_page_seen
;

SELECT * FROM product_funnel_session;

-- 6. calculate the clickthrough rate 

SELECT 
	product_page_seen,
    cart_page_sessions / product_page_sessions AS product_page_clickthro_rate,
    shipping_page_sessions / cart_page_sessions AS cart_page_clickthro_rate,
    billing2_page_sessions / shipping_page_sessions AS shipping_page_clickthro_rate,
    order_page_sessions / billing2_page_sessions AS billing2_page_clickthro_rate
FROM product_funnel_session;