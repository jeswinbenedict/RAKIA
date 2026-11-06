-- SPDX-License-Identifier: Apache-2.0
--
-- 0002 schema version: lets the API check, before it reports ready, that
-- the database has the schema it was built for. rakia_api still cannot
-- read the migration history itself; it learns only the latest version.

SET search_path = rakia;

CREATE FUNCTION schema_version() RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
  SELECT coalesce(max(version), 0) FROM schema_migrations
$$;

REVOKE ALL ON FUNCTION schema_version() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION schema_version() TO rakia_api;
