-- SPDX-License-Identifier: Apache-2.0
--
-- Run once as each RAKIA role right after bootstrap: proves the new password
-- works and that the role has exactly the privileges it should. Fails
-- (non-zero exit) on any deviation.

\set ON_ERROR_STOP on
\set QUIET on

DO $$
DECLARE
  r pg_roles%ROWTYPE;
  migrator boolean := current_user = 'rakia_migrator';
BEGIN
  SELECT * INTO r FROM pg_roles WHERE rolname = current_user;
  IF current_user NOT IN ('rakia_api', 'rakia_migrator')
     OR current_database() <> 'rakia' THEN
    RAISE EXCEPTION 'connected as %/% instead of a RAKIA role on rakia',
      current_user, current_database();
  END IF;
  IF r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolbypassrls
     OR r.rolreplication THEN
    RAISE EXCEPTION '% has more than least privilege', current_user;
  END IF;
  IF current_setting('search_path') <> 'rakia' THEN
    RAISE EXCEPTION 'unexpected search_path %', current_setting('search_path');
  END IF;
  IF NOT has_schema_privilege('rakia', 'USAGE') THEN
    RAISE EXCEPTION '% cannot use schema rakia', current_user;
  END IF;
  IF has_schema_privilege('public', 'CREATE') THEN
    RAISE EXCEPTION '% can create objects in public', current_user;
  END IF;
  IF has_schema_privilege('rakia', 'CREATE') <> migrator THEN
    RAISE EXCEPTION 'CREATE on schema rakia is wrong for %', current_user;
  END IF;
  IF NOT migrator AND (has_database_privilege('rakia', 'CREATE')
                       OR has_database_privilege('rakia', 'TEMPORARY')) THEN
    RAISE EXCEPTION 'rakia_api has database CREATE or TEMPORARY';
  END IF;
END
$$;

SELECT 'verified ' || current_user || ' on ' || current_database()
  || ' (PostgreSQL ' || current_setting('server_version') || ')' AS result;
