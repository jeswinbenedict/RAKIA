-- SPDX-License-Identifier: Apache-2.0
--
-- Creates (or repairs) the local development database for RAKIA:
--   rakia_migrator  owns the database and the `rakia` schema; runs migrations.
--   rakia_api       least privilege: may connect and use the schema; table
--                   privileges are granted by the migrations themselves.
-- Neither role is a superuser, can create databases or roles, or bypass
-- row-level security.
--
-- Run by bootstrap-local.ps1 / bootstrap-local.sh as a superuser, which set
-- the psql variables :migrator_password and :api_password. Passwords are
-- passed as variables and quoted by psql (:'name'), never spliced into SQL.
-- Safe to run again: existing roles get the new passwords and their
-- attributes are reset to the ones below.

\set ON_ERROR_STOP on
\set QUIET on

SET client_min_messages = warning;

-- Store only SCRAM verifiers, never MD5.
SET password_encryption = 'scram-sha-256';

SELECT 'CREATE ROLE rakia_migrator'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rakia_migrator')
\gexec
SELECT 'CREATE ROLE rakia_api'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rakia_api')
\gexec

ALTER ROLE rakia_migrator
  LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS INHERIT
  PASSWORD :'migrator_password';
ALTER ROLE rakia_api
  LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS NOINHERIT
  PASSWORD :'api_password';

SELECT 'CREATE DATABASE rakia OWNER rakia_migrator ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rakia')
\gexec
ALTER DATABASE rakia OWNER TO rakia_migrator;

-- Only the two RAKIA roles may connect.
REVOKE ALL ON DATABASE rakia FROM PUBLIC;
GRANT CONNECT ON DATABASE rakia TO rakia_migrator, rakia_api;
GRANT TEMPORARY ON DATABASE rakia TO rakia_migrator;

\connect rakia
SET client_min_messages = warning;

-- Nothing lives in `public`. Since PostgreSQL 15 it belongs to the database
-- owner (rakia_migrator); hand it to the bootstrapping superuser so neither
-- RAKIA role can create objects there.
ALTER SCHEMA public OWNER TO CURRENT_USER;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS rakia AUTHORIZATION rakia_migrator;
ALTER SCHEMA rakia OWNER TO rakia_migrator;
REVOKE ALL ON SCHEMA rakia FROM PUBLIC;
GRANT USAGE ON SCHEMA rakia TO rakia_api;

ALTER ROLE rakia_migrator IN DATABASE rakia SET search_path = rakia;
ALTER ROLE rakia_api IN DATABASE rakia SET search_path = rakia;
