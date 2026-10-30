\i common/common_setup.sql

-- A comparison bound beyond every value a Numeric64 column holds is not an error. Every
-- NUMERIC(18,18) value lies strictly between -1 and 1, and 10 scaled by 10^18 does not fit an
-- i64, so the bound alone decides whether the comparison matches every row or none.
-- https://github.com/paradedb/paradedb/issues/7046

CREATE TABLE numeric_scale_case (
    id int PRIMARY KEY,
    body text,
    n numeric(18, 18)
);

INSERT INTO numeric_scale_case VALUES
    (1, 'foo', 0.123456789012345678),
    (2, 'foo', 0.999999999999999999),
    (3, 'none', 0.000000000000000001),
    (4, 'foo', -0.999999999999999999),
    (5, 'foo', NULL);

CREATE INDEX numeric_scale_case_idx ON numeric_scale_case
USING paradedb (id, body, n)
WITH (numeric_fields = '{"n": {"fast": true}}');

ANALYZE numeric_scale_case;

SET paradedb.enable_aggregate_custom_scan = off;

EXPLAIN (COSTS OFF, VERBOSE, TIMING OFF)
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n > 10 ORDER BY id LIMIT 10;

-- Above every value: > and >= match nothing, < and <= match every non-NULL row.
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n > 10 ORDER BY id LIMIT 10;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n >= 10 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n < 10 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n <= 10 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n = 10 ORDER BY id;

-- Below every value: the mirror image.
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n < -10 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n <= -10 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n > -10 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n >= -10 ORDER BY id;

-- 1 and -1 are the first bounds past the largest and smallest values the column holds.
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n >= 1 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n < 1 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n <= -1 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n > -1 ORDER BY id;

-- The largest and smallest values the column holds are still matched exactly.
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n >= 0.999999999999999999 ORDER BY id;
SELECT id FROM numeric_scale_case
WHERE body @@@ 'foo' AND n <= -0.999999999999999999 ORDER BY id;

-- PostgreSQL's own answers, without the index, for comparison.
SET paradedb.enable_custom_scan = off;
SELECT
    count(*) FILTER (WHERE n > 10) AS gt,
    count(*) FILTER (WHERE n >= 10) AS ge,
    count(*) FILTER (WHERE n < 10) AS lt,
    count(*) FILTER (WHERE n <= 10) AS le,
    count(*) FILTER (WHERE n = 10) AS eq,
    count(*) FILTER (WHERE n < -10) AS lt_neg,
    count(*) FILTER (WHERE n <= -10) AS le_neg,
    count(*) FILTER (WHERE n > -10) AS gt_neg,
    count(*) FILTER (WHERE n >= -10) AS ge_neg
FROM numeric_scale_case
WHERE body = 'foo';
RESET paradedb.enable_custom_scan;

DROP TABLE numeric_scale_case;
RESET paradedb.enable_aggregate_custom_scan;

\i common/common_cleanup.sql
