-- FUNCTION: public._final_median(numeric[])

-- DROP FUNCTION public._final_median(numeric[]);

CREATE OR REPLACE FUNCTION public._final_median(
	numeric[])
    RETURNS numeric
    LANGUAGE 'sql'

    COST 100
    IMMUTABLE 
AS $BODY$
   SELECT AVG(val)
   FROM (
     SELECT val
     FROM unnest($1) val
     ORDER BY 1
     LIMIT  2 - MOD(array_upper($1, 1), 2)
     OFFSET CEIL(array_upper($1, 1) / 2.0) - 1
   ) sub;
$BODY$;
