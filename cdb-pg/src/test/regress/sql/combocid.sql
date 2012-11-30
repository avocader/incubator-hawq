--
-- Tests for some likely failure cases with combo cmin/cmax mechanism
--
CREATE TEMP TABLE combocidtest (a int, foobar int);

BEGIN;

-- a few dummy ops to push up the CommandId counter
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;

INSERT INTO combocidtest VALUES (1,1);
INSERT INTO combocidtest VALUES (2,2);

SELECT ctid,cmin,* FROM combocidtest;

SAVEPOINT s1;

UPDATE combocidtest SET foobar = foobar + 10;

-- here we should see only updated tuples
SELECT ctid,cmin,* FROM combocidtest;

ROLLBACK TO s1;

-- now we should see old tuples, but with combo CIDs starting at 0
SELECT ctid,cmin,* FROM combocidtest;

COMMIT;

-- combo data is not there anymore, but should still see tuples
SELECT ctid,cmin,* FROM combocidtest;

-- Test combo cids with portals
BEGIN;

INSERT INTO combocidtest VALUES (3,333);

DECLARE c CURSOR FOR SELECT ctid,cmin,* FROM combocidtest ORDER BY a;

DELETE FROM combocidtest;

FETCH ALL FROM c;

ROLLBACK;

SELECT ctid,cmin,* FROM combocidtest ORDER BY a;

-- check behavior with locked tuples
BEGIN;

-- a few dummy ops to push up the CommandId counter
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;
SELECT count(*) from combocidtest;

INSERT INTO combocidtest VALUES (3,444);

SELECT ctid,cmin,* FROM combocidtest ORDER BY a;

SAVEPOINT s1;

-- this doesn't affect cmin
SELECT ctid,cmin,* FROM combocidtest ORDER BY a FOR UPDATE;
SELECT ctid,cmin,* FROM combocidtest ORDER BY a;

-- but this does
UPDATE combocidtest SET foobar = foobar + 10;

SELECT ctid,cmin,* FROM combocidtest ORDER BY a;

ROLLBACK TO s1;

SELECT ctid,cmin,* FROM combocidtest ORDER BY a;

COMMIT;

SELECT ctid,cmin,* FROM combocidtest ORDER BY a;
