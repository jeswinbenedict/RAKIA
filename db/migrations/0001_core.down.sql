-- SPDX-License-Identifier: Apache-2.0
--
-- Reverts 0001 core. Destroys every table it created and their data; meant
-- for development databases. The schema itself belongs to the bootstrap.

SET search_path = rakia;

DROP TABLE IF EXISTS turnstile_replay, audit_log, alert_events, alerts, sync_batches,
  measurements, clients, devices, data_sources, metric_definitions, crew_members,
  mission_members, missions, app_users CASCADE;

DROP FUNCTION IF EXISTS verify_audit_chain(), audit_log_append_only(), audit(),
  audit_row_hash(bytea, timestamptz, text, text, text, text, jsonb, jsonb),
  alert_events_apply(), alerts_status_only(), measurements_delete_simulation_only(),
  measurements_immutable(), measurements_check_insert(), missions_delete_simulation_only(),
  missions_identity_immutable(), mission_is_unclaimed(uuid), can_read_health(uuid, uuid),
  is_mission_member(uuid), has_mission_role(uuid, member_role[]), current_user_id(),
  current_uid();

DROP TYPE IF EXISTS alert_status, alert_level, provenance, measurement_method, member_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA rakia GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
