-- SPDX-License-Identifier: Apache-2.0
--
-- 0001 core: identities, missions and membership, measurements with the
-- simulation firewall and a per-client hash chain, alerts, sync batches,
-- the append-only audit log and Turnstile replay protection.
--
-- Runs as rakia_migrator, which owns every object. rakia_api gets only the
-- privileges granted here and is subject to row-level security. The caller
-- is identified by the Firebase uid the API places in the transaction-local
-- setting request.jwt.claims (the mechanism Supabase uses), after verifying
-- the caller's ID token.

SET search_path = rakia;

-- Functions are not executable by PUBLIC unless granted below.
ALTER DEFAULT PRIVILEGES IN SCHEMA rakia REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- ------------------------------------------------------------------ types

CREATE TYPE member_role AS ENUM (
  'astronaut', 'crew_medical_officer', 'flight_surgeon', 'researcher',
  'mission_admin'
);
CREATE TYPE measurement_method AS ENUM ('measured', 'manual', 'estimated', 'derived');
CREATE TYPE provenance AS ENUM ('real', 'imported', 'simulated');
-- librakia's rakia_level values that warrant an alert.
CREATE TYPE alert_level AS ENUM ('data_quality', 'watch', 'act');
CREATE TYPE alert_status AS ENUM ('open', 'acknowledged', 'resolved', 'dismissed');

-- ------------------------------------------------- caller identity helpers

-- The verified Firebase uid of the caller, or NULL outside a request.
CREATE FUNCTION current_uid() RETURNS text
LANGUAGE sql STABLE
SET search_path = rakia, pg_temp
AS $$
  SELECT nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
$$;

-- ------------------------------------------------------------------ tables

CREATE TABLE app_users (
  id           uuid PRIMARY KEY,
  firebase_uid text NOT NULL UNIQUE CHECK (length(firebase_uid) BETWEEN 1 AND 128),
  display_name text CHECK (length(display_name) <= 200),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE missions (
  id              uuid PRIMARY KEY,
  name            text NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
  is_simulation   boolean NOT NULL,
  simulation_seed bigint,
  starts_at       timestamptz NOT NULL,
  planned_days    integer NOT NULL CHECK (planned_days BETWEEN 1 AND 3650),
  created_by      uuid NOT NULL REFERENCES app_users (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (is_simulation OR simulation_seed IS NULL)
);

CREATE TABLE mission_members (
  mission_id uuid NOT NULL REFERENCES missions (id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES app_users (id),
  role       member_role NOT NULL,
  added_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (mission_id, user_id, role)
);
CREATE INDEX mission_members_by_user ON mission_members (user_id);

-- A crew member is a monitored person in a mission, linked to the
-- astronaut's account when they have one. `label` is a pseudonymous name.
CREATE TABLE crew_members (
  id         uuid PRIMARY KEY,
  mission_id uuid NOT NULL REFERENCES missions (id) ON DELETE CASCADE,
  user_id    uuid REFERENCES app_users (id),
  label      text NOT NULL CHECK (length(label) BETWEEN 1 AND 100),
  UNIQUE (mission_id, label),
  UNIQUE (mission_id, user_id),
  UNIQUE (id, mission_id)
);

CREATE TABLE metric_definitions (
  code          text PRIMARY KEY CHECK (code ~ '^[a-z0-9_]+(\.[a-z0-9_]+)*$'),
  name          text NOT NULL,
  unit          text NOT NULL,
  ucum          text NOT NULL,
  plausible_min double precision NOT NULL,
  plausible_max double precision NOT NULL,
  CHECK (plausible_min < plausible_max)
);

-- The same five indicators, codes and units as the app
-- (app/lib/analytics/metric_definitions.dart).
INSERT INTO metric_definitions (code, name, unit, ucum, plausible_min, plausible_max) VALUES
  ('heart_rate.resting', 'Resting heart rate', 'bpm', '/min', 30, 120),
  ('hrv.rmssd', 'Heart-rate variability (RMSSD)', 'ms', 'ms', 5, 250),
  ('spo2', 'Oxygen saturation', '%', '%', 70, 100),
  ('sleep.duration', 'Sleep duration', 'h', 'h', 0.5, 16),
  ('exercise.duration', 'Exercise', 'min', 'min', 0, 300);

CREATE TABLE data_sources (
  id   uuid PRIMARY KEY,
  kind text NOT NULL CHECK (kind IN ('wearable', 'manual', 'import', 'simulation')),
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 200)
);

CREATE TABLE devices (
  id        uuid PRIMARY KEY,
  source_id uuid NOT NULL REFERENCES data_sources (id),
  model     text NOT NULL CHECK (length(model) BETWEEN 1 AND 200)
);

-- An installation of the app. Each client keeps one hash chain per mission.
CREATE TABLE clients (
  id         uuid PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES app_users (id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE measurements (
  id             uuid PRIMARY KEY,
  mission_id     uuid NOT NULL REFERENCES missions (id) ON DELETE CASCADE,
  crew_member_id uuid NOT NULL,
  metric_code    text NOT NULL REFERENCES metric_definitions (code),
  value          double precision NOT NULL
                   CHECK (value <> 'NaN' AND value > '-Infinity' AND value < 'Infinity'),
  unit           text NOT NULL,
  observed_at    timestamptz NOT NULL,
  received_at    timestamptz NOT NULL DEFAULT now(),
  device_id      uuid REFERENCES devices (id),
  source_id      uuid REFERENCES data_sources (id),
  method         measurement_method NOT NULL,
  provenance     provenance NOT NULL,
  quality_score  real CHECK (quality_score BETWEEN 0 AND 1),
  -- Bit flags, as on the device (bit 0: sensor fault).
  quality_flags  integer NOT NULL DEFAULT 0 CHECK (quality_flags >= 0),
  client_id      uuid NOT NULL REFERENCES clients (id),
  client_seq     bigint NOT NULL CHECK (client_seq >= 1),
  prev_hash      bytea NOT NULL CHECK (length(prev_hash) = 32),
  hash           bytea NOT NULL CHECK (length(hash) = 32),
  supersedes_id  uuid REFERENCES measurements (id),
  FOREIGN KEY (crew_member_id, mission_id) REFERENCES crew_members (id, mission_id) ON DELETE CASCADE,
  UNIQUE (client_id, mission_id, client_seq),
  CHECK (supersedes_id IS NULL OR supersedes_id <> id)
);
CREATE INDEX measurements_by_series ON measurements (crew_member_id, metric_code, observed_at DESC);
CREATE INDEX measurements_observed_brin ON measurements USING brin (observed_at);
CREATE INDEX measurements_mission ON measurements (mission_id);

CREATE TABLE sync_batches (
  id               uuid PRIMARY KEY,
  client_id        uuid NOT NULL REFERENCES clients (id),
  mission_id       uuid NOT NULL REFERENCES missions (id) ON DELETE CASCADE,
  record_count     integer NOT NULL CHECK (record_count >= 0),
  acked_through_seq bigint NOT NULL CHECK (acked_through_seq >= 0),
  received_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE alerts (
  id             uuid PRIMARY KEY,
  mission_id     uuid NOT NULL REFERENCES missions (id) ON DELETE CASCADE,
  crew_member_id uuid NOT NULL,
  metric_code    text NOT NULL REFERENCES metric_definitions (code),
  level          alert_level NOT NULL,
  status         alert_status NOT NULL DEFAULT 'open',
  onset_at       timestamptz,
  -- The six parts shown to the user, produced from librakia's outputs.
  explanation    jsonb NOT NULL CHECK (
    jsonb_typeof(explanation) = 'object' AND explanation ?& ARRAY[
      'what_changed', 'by_how_much', 'since', 'evidence', 'why_it_matters', 'check_next'
    ]),
  engine_version text NOT NULL CHECK (length(engine_version) BETWEEN 1 AND 50),
  created_at     timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (crew_member_id, mission_id) REFERENCES crew_members (id, mission_id) ON DELETE CASCADE
);
CREATE INDEX alerts_by_mission ON alerts (mission_id, status);

CREATE TABLE alert_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  alert_id    uuid NOT NULL REFERENCES alerts (id) ON DELETE CASCADE,
  actor_id    uuid NOT NULL REFERENCES app_users (id),
  from_status alert_status NOT NULL,
  to_status   alert_status NOT NULL,
  note        text CHECK (length(note) <= 2000),
  at          timestamptz NOT NULL DEFAULT now(),
  CHECK (from_status <> to_status)
);

-- Append-only, hash-chained record of changes to sensitive tables.
CREATE TABLE audit_log (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  at         timestamptz NOT NULL DEFAULT clock_timestamp(),
  actor      text NOT NULL,
  table_name text NOT NULL,
  action     text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  row_key    text,
  before     jsonb,
  after      jsonb,
  prev_hash  bytea NOT NULL CHECK (length(prev_hash) = 32),
  hash       bytea NOT NULL CHECK (length(hash) = 32)
);

-- SHA-256 of Turnstile tokens seen recently, to refuse replays.
CREATE TABLE turnstile_replay (
  token_hash bytea PRIMARY KEY CHECK (length(token_hash) = 32),
  expires_at timestamptz NOT NULL
);
CREATE INDEX turnstile_replay_expiry ON turnstile_replay (expires_at);

-- --------------------------------------- membership helpers (for policies)
-- SECURITY DEFINER so policies can consult membership without recursing
-- into mission_members' own policies. They only answer questions about the
-- caller.

CREATE FUNCTION current_user_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
  SELECT id FROM app_users WHERE firebase_uid = current_uid()
$$;

CREATE FUNCTION has_mission_role(p_mission uuid, p_roles member_role[]) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
  SELECT EXISTS (
    SELECT FROM mission_members
    WHERE mission_id = p_mission AND user_id = current_user_id() AND role = ANY (p_roles))
$$;

CREATE FUNCTION is_mission_member(p_mission uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
  SELECT EXISTS (
    SELECT FROM mission_members
    WHERE mission_id = p_mission AND user_id = current_user_id())
$$;

-- Whether the caller may read a crew member's health data: the astronaut
-- themself, or the mission's medical staff.
CREATE FUNCTION can_read_health(p_mission uuid, p_crew uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
  SELECT has_mission_role(p_mission, '{crew_medical_officer,flight_surgeon}')
      OR EXISTS (
        SELECT FROM crew_members
        WHERE id = p_crew AND mission_id = p_mission
          AND user_id = current_user_id()
          AND has_mission_role(p_mission, '{astronaut}'))
$$;

-- True when the mission has no members yet: its creator may then add
-- themself as mission_admin.
CREATE FUNCTION mission_is_unclaimed(p_mission uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
  SELECT NOT EXISTS (SELECT FROM mission_members WHERE mission_id = p_mission)
     AND EXISTS (SELECT FROM missions WHERE id = p_mission AND created_by = current_user_id())
$$;

-- ---------------------------------------------------------- integrity rules

CREATE FUNCTION missions_identity_immutable() RETURNS trigger
LANGUAGE plpgsql
SET search_path = rakia, pg_temp
AS $$
BEGIN
  IF NEW.id <> OLD.id OR NEW.is_simulation <> OLD.is_simulation
     OR NEW.simulation_seed IS DISTINCT FROM OLD.simulation_seed
     OR NEW.created_by <> OLD.created_by THEN
    RAISE EXCEPTION 'rakia: a mission''s identity and simulation status cannot change'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END
$$;
CREATE TRIGGER missions_identity_immutable BEFORE UPDATE ON missions
  FOR EACH ROW EXECUTE FUNCTION missions_identity_immutable();

-- Real missions are never deleted; simulation missions may be.
CREATE FUNCTION missions_delete_simulation_only() RETURNS trigger
LANGUAGE plpgsql
SET search_path = rakia, pg_temp
AS $$
BEGIN
  IF NOT OLD.is_simulation THEN
    RAISE EXCEPTION 'rakia: only simulation missions can be deleted'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END
$$;
CREATE TRIGGER missions_delete_simulation_only BEFORE DELETE ON missions
  FOR EACH ROW EXECUTE FUNCTION missions_delete_simulation_only();

-- Every rule a new measurement must meet. SECURITY DEFINER so the chain is
-- checked against all of the client's records, not only those the caller
-- may read.
CREATE FUNCTION measurements_check_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
DECLARE
  sim  boolean;
  def  metric_definitions%ROWTYPE;
  prev measurements%ROWTYPE;
  old  measurements%ROWTYPE;
BEGIN
  SELECT is_simulation INTO sim FROM missions WHERE id = NEW.mission_id;
  IF sim AND NEW.provenance <> 'simulated' THEN
    RAISE EXCEPTION 'rakia: a simulation mission accepts only simulated measurements'
      USING ERRCODE = 'check_violation';
  ELSIF NOT sim AND NEW.provenance = 'simulated' THEN
    RAISE EXCEPTION 'rakia: simulated measurements are not accepted in a real mission'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT * INTO def FROM metric_definitions WHERE code = NEW.metric_code;
  IF NEW.unit <> def.unit THEN
    RAISE EXCEPTION 'rakia: % is recorded in %, not %', NEW.metric_code, def.unit, NEW.unit
      USING ERRCODE = 'check_violation';
  END IF;

  -- The client's chain for this mission continues exactly where it ended.
  SELECT * INTO prev FROM measurements
  WHERE client_id = NEW.client_id AND mission_id = NEW.mission_id
  ORDER BY client_seq DESC LIMIT 1;
  IF NEW.client_seq <> coalesce(prev.client_seq, 0) + 1 THEN
    RAISE EXCEPTION 'rakia: chain gap: expected sequence %, got %',
      coalesce(prev.client_seq, 0) + 1, NEW.client_seq
      USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.prev_hash <> coalesce(prev.hash, '\x0000000000000000000000000000000000000000000000000000000000000000'::bytea) THEN
    RAISE EXCEPTION 'rakia: chain break at sequence %: prev_hash does not match', NEW.client_seq
      USING ERRCODE = 'check_violation';
  END IF;

  IF NEW.supersedes_id IS NOT NULL THEN
    SELECT * INTO old FROM measurements WHERE id = NEW.supersedes_id;
    IF old.mission_id <> NEW.mission_id OR old.crew_member_id <> NEW.crew_member_id
       OR old.metric_code <> NEW.metric_code THEN
      RAISE EXCEPTION 'rakia: a correction must supersede a record of the same series'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END
$$;
CREATE TRIGGER measurements_check_insert BEFORE INSERT ON measurements
  FOR EACH ROW EXECUTE FUNCTION measurements_check_insert();

CREATE FUNCTION measurements_immutable() RETURNS trigger
LANGUAGE plpgsql
SET search_path = rakia, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'rakia: measurements are immutable; record a correction that supersedes it'
    USING ERRCODE = 'check_violation';
END
$$;
CREATE TRIGGER measurements_immutable BEFORE UPDATE ON measurements
  FOR EACH ROW EXECUTE FUNCTION measurements_immutable();

CREATE FUNCTION measurements_delete_simulation_only() RETURNS trigger
LANGUAGE plpgsql
SET search_path = rakia, pg_temp
AS $$
BEGIN
  IF OLD.provenance <> 'simulated' THEN
    RAISE EXCEPTION 'rakia: only simulated measurements can be deleted'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END
$$;
CREATE TRIGGER measurements_delete_simulation_only BEFORE DELETE ON measurements
  FOR EACH ROW EXECUTE FUNCTION measurements_delete_simulation_only();

-- An alert's status changes only along with an alert_events row.
CREATE FUNCTION alerts_status_only() RETURNS trigger
LANGUAGE plpgsql
SET search_path = rakia, pg_temp
AS $$
BEGIN
  IF (to_jsonb(NEW) - 'status') <> (to_jsonb(OLD) - 'status') THEN
    RAISE EXCEPTION 'rakia: only an alert''s status can change'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END
$$;
CREATE TRIGGER alerts_status_only BEFORE UPDATE ON alerts
  FOR EACH ROW EXECUTE FUNCTION alerts_status_only();

-- Recording an alert event applies the status change, so the two cannot
-- disagree.
CREATE FUNCTION alert_events_apply() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
DECLARE
  current alert_status;
BEGIN
  SELECT status INTO current FROM alerts WHERE id = NEW.alert_id FOR UPDATE;
  IF current <> NEW.from_status THEN
    RAISE EXCEPTION 'rakia: the alert is %, not %', current, NEW.from_status
      USING ERRCODE = 'serialization_failure';
  END IF;
  UPDATE alerts SET status = NEW.to_status WHERE id = NEW.alert_id;
  RETURN NEW;
END
$$;
CREATE TRIGGER alert_events_apply BEFORE INSERT ON alert_events
  FOR EACH ROW EXECUTE FUNCTION alert_events_apply();

-- -------------------------------------------------------------- audit log

CREATE FUNCTION audit_row_hash(
  p_prev bytea, p_at timestamptz, p_actor text, p_table text, p_action text,
  p_key text, p_before jsonb, p_after jsonb
) RETURNS bytea
LANGUAGE sql IMMUTABLE
SET search_path = rakia, pg_temp
AS $$
  SELECT sha256(p_prev || convert_to(jsonb_build_array(
    to_char(p_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    p_actor, p_table, p_action, p_key, p_before, p_after)::text, 'UTF8'))
$$;

CREATE FUNCTION audit() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = rakia, pg_temp
AS $$
DECLARE
  v_prev   bytea;
  v_at     timestamptz := clock_timestamp();
  v_actor  text := coalesce(current_uid(), session_user::text);
  v_before jsonb := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END;
  v_after  jsonb := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END;
  v_key    text := coalesce(v_after, v_before) ->> 'id';
BEGIN
  IF v_key IS NULL AND TG_TABLE_NAME = 'mission_members' THEN
    v_key := concat_ws('/', coalesce(v_after, v_before) ->> 'mission_id',
                       coalesce(v_after, v_before) ->> 'user_id',
                       coalesce(v_after, v_before) ->> 'role');
  END IF;
  -- One writer at a time extends the chain.
  PERFORM pg_advisory_xact_lock(hashtext('rakia.audit_log'));
  SELECT hash INTO v_prev FROM audit_log ORDER BY id DESC LIMIT 1;
  v_prev := coalesce(v_prev, '\x0000000000000000000000000000000000000000000000000000000000000000'::bytea);
  INSERT INTO audit_log (at, actor, table_name, action, row_key, before, after, prev_hash, hash)
  VALUES (v_at, v_actor, TG_TABLE_NAME, TG_OP, v_key, v_before, v_after, v_prev,
          audit_row_hash(v_prev, v_at, v_actor, TG_TABLE_NAME, TG_OP, v_key, v_before, v_after));
  RETURN NULL;
END
$$;

CREATE TRIGGER audit AFTER INSERT OR UPDATE OR DELETE ON missions
  FOR EACH ROW EXECUTE FUNCTION audit();
CREATE TRIGGER audit AFTER INSERT OR UPDATE OR DELETE ON mission_members
  FOR EACH ROW EXECUTE FUNCTION audit();
CREATE TRIGGER audit AFTER INSERT OR UPDATE OR DELETE ON crew_members
  FOR EACH ROW EXECUTE FUNCTION audit();
CREATE TRIGGER audit AFTER INSERT OR UPDATE OR DELETE ON alerts
  FOR EACH ROW EXECUTE FUNCTION audit();
-- Measurements carry their own hash chain; deletions are audited.
CREATE TRIGGER audit AFTER DELETE ON measurements
  FOR EACH ROW EXECUTE FUNCTION audit();

CREATE FUNCTION audit_log_append_only() RETURNS trigger
LANGUAGE plpgsql
SET search_path = rakia, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'rakia: the audit log is append-only'
    USING ERRCODE = 'insufficient_privilege';
END
$$;
CREATE TRIGGER audit_log_append_only BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION audit_log_append_only();
CREATE TRIGGER audit_log_no_truncate BEFORE TRUNCATE ON audit_log
  FOR EACH STATEMENT EXECUTE FUNCTION audit_log_append_only();

-- The id of the first audit entry whose hash or link does not verify, or
-- NULL when the whole chain verifies. For operators (rakia_migrator).
CREATE FUNCTION verify_audit_chain() RETURNS bigint
LANGUAGE plpgsql STABLE
SET search_path = rakia, pg_temp
AS $$
DECLARE
  r    audit_log%ROWTYPE;
  prev bytea := '\x0000000000000000000000000000000000000000000000000000000000000000'::bytea;
BEGIN
  FOR r IN SELECT * FROM audit_log ORDER BY id LOOP
    IF r.prev_hash <> prev OR r.hash <> audit_row_hash(
         r.prev_hash, r.at, r.actor, r.table_name, r.action, r.row_key, r.before, r.after) THEN
      RETURN r.id;
    END IF;
    prev := r.hash;
  END LOOP;
  RETURN NULL;
END
$$;

-- ------------------------------------------------------- row-level security

ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mission_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE crew_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY own_account ON app_users
  USING (firebase_uid = current_uid())
  WITH CHECK (firebase_uid = current_uid());

CREATE POLICY members_read ON missions FOR SELECT
  USING (is_mission_member(id) OR created_by = current_user_id());
CREATE POLICY create_own ON missions FOR INSERT
  WITH CHECK (created_by = current_user_id());
CREATE POLICY admin_update ON missions FOR UPDATE
  USING (has_mission_role(id, '{mission_admin}'));
CREATE POLICY admin_delete_simulation ON missions FOR DELETE
  USING (is_simulation AND has_mission_role(id, '{mission_admin}'));

CREATE POLICY members_read ON mission_members FOR SELECT
  USING (is_mission_member(mission_id));
CREATE POLICY admin_add ON mission_members FOR INSERT
  WITH CHECK (has_mission_role(mission_id, '{mission_admin}')
    OR (mission_is_unclaimed(mission_id) AND user_id = current_user_id()
        AND role = 'mission_admin'));
CREATE POLICY admin_remove ON mission_members FOR DELETE
  USING (has_mission_role(mission_id, '{mission_admin}'));

CREATE POLICY members_read ON crew_members FOR SELECT
  USING (is_mission_member(mission_id));
CREATE POLICY admin_write ON crew_members FOR INSERT
  WITH CHECK (has_mission_role(mission_id, '{mission_admin}'));
CREATE POLICY admin_update ON crew_members FOR UPDATE
  USING (has_mission_role(mission_id, '{mission_admin}'));

CREATE POLICY own_clients ON clients
  USING (user_id = current_user_id())
  WITH CHECK (user_id = current_user_id());

CREATE POLICY health_read ON measurements FOR SELECT
  USING (can_read_health(mission_id, crew_member_id));
CREATE POLICY own_client_write ON measurements FOR INSERT
  WITH CHECK (can_read_health(mission_id, crew_member_id)
    AND EXISTS (SELECT FROM clients c WHERE c.id = client_id AND c.user_id = current_user_id()));
CREATE POLICY admin_delete_simulation ON measurements FOR DELETE
  USING (provenance = 'simulated' AND has_mission_role(mission_id, '{mission_admin}'));

CREATE POLICY own_batches ON sync_batches
  USING (EXISTS (SELECT FROM clients c WHERE c.id = client_id AND c.user_id = current_user_id()))
  WITH CHECK (EXISTS (SELECT FROM clients c WHERE c.id = client_id AND c.user_id = current_user_id())
    AND is_mission_member(mission_id));

CREATE POLICY health_read ON alerts FOR SELECT
  USING (can_read_health(mission_id, crew_member_id));
CREATE POLICY health_write ON alerts FOR INSERT
  WITH CHECK (can_read_health(mission_id, crew_member_id));

CREATE POLICY health_read ON alert_events FOR SELECT
  USING (EXISTS (SELECT FROM alerts a WHERE a.id = alert_id
                 AND can_read_health(a.mission_id, a.crew_member_id)));
CREATE POLICY medical_staff_write ON alert_events FOR INSERT
  WITH CHECK (actor_id = current_user_id() AND EXISTS (
    SELECT FROM alerts a WHERE a.id = alert_id
      AND has_mission_role(a.mission_id, '{crew_medical_officer,flight_surgeon}')));

-- audit_log: RLS on and no policy, so rakia_api sees nothing.

-- ---------------------------------------------------------------- grants

GRANT EXECUTE ON FUNCTION current_uid(), current_user_id(), has_mission_role(uuid, member_role[]),
  is_mission_member(uuid), can_read_health(uuid, uuid), mission_is_unclaimed(uuid) TO rakia_api;

GRANT SELECT, INSERT ON app_users TO rakia_api;
GRANT UPDATE (display_name) ON app_users TO rakia_api;
GRANT SELECT, INSERT, DELETE ON missions TO rakia_api;
GRANT UPDATE (name, planned_days) ON missions TO rakia_api;
GRANT SELECT, INSERT, DELETE ON mission_members TO rakia_api;
GRANT SELECT, INSERT ON crew_members TO rakia_api;
GRANT UPDATE (label, user_id) ON crew_members TO rakia_api;
GRANT SELECT ON metric_definitions, data_sources, devices TO rakia_api;
GRANT SELECT, INSERT ON clients TO rakia_api;
GRANT SELECT, INSERT, DELETE ON measurements TO rakia_api;
GRANT SELECT, INSERT ON sync_batches TO rakia_api;
GRANT SELECT, INSERT ON alerts TO rakia_api;
GRANT SELECT, INSERT ON alert_events TO rakia_api;
GRANT SELECT, INSERT, DELETE ON turnstile_replay TO rakia_api;
