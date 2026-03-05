-- ============================================================
-- Activity Contest App - Full Database Migration
-- Drops ALL old structures and creates new schema from scratch
-- Run this in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. DROP OLD STRUCTURES
-- ============================================================

DROP VIEW IF EXISTS "TeamsDistance" CASCADE;
DROP VIEW IF EXISTS "PeopleDistances" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "TeamsDistance" CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "PeopleDistances" CASCADE;
DROP TABLE IF EXISTS "Distance" CASCADE;
DROP TABLE IF EXISTS "People" CASCADE;

-- Drop new tables too (for re-runnability)
DROP MATERIALIZED VIEW IF EXISTS mv_people_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_team_stats CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS activity_types CASCADE;
DROP TABLE IF EXISTS people CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS app_config CASCADE;

-- ============================================================
-- 2. CREATE NEW TABLES
-- ============================================================

-- App configuration (editable thresholds and settings)
CREATE TABLE app_config (
    id SERIAL PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Teams (dynamic, admin-managed)
CREATE TABLE teams (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#6B7280',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Activity types with point multipliers
CREATE TABLE activity_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    multiplier NUMERIC(5,2) NOT NULL DEFAULT 1.0,
    icon TEXT DEFAULT 'activity',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- People (linked to Supabase Auth)
CREATE TABLE people (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    team_id INT REFERENCES teams(id) ON DELETE SET NULL,
    is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Activities (core data - each logged activity)
CREATE TABLE activities (
    id SERIAL PRIMARY KEY,
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    team_id INT REFERENCES teams(id) ON DELETE SET NULL,
    activity_type_id INT NOT NULL REFERENCES activity_types(id) ON DELETE RESTRICT,
    value NUMERIC(10,2) NOT NULL,
    points NUMERIC(10,2) NOT NULL,
    proof_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. INDEXES
-- ============================================================

CREATE INDEX idx_activities_person ON activities(person_id);
CREATE INDEX idx_activities_team ON activities(team_id);
CREATE INDEX idx_activities_created ON activities(created_at);
CREATE INDEX idx_activities_person_created ON activities(person_id, created_at);
CREATE INDEX idx_people_team ON people(team_id);

-- ============================================================
-- 4. MATERIALIZED VIEWS
-- ============================================================

CREATE MATERIALIZED VIEW mv_people_stats AS
SELECT
    p.id AS person_id,
    p.name,
    p.team_id,
    COALESCE(SUM(a.points), 0) AS total_points,
    MAX(a.created_at) AS last_activity,
    COUNT(DISTINCT DATE(a.created_at)) AS active_days
FROM people p
LEFT JOIN activities a ON a.person_id = p.id
GROUP BY p.id, p.name, p.team_id;

CREATE UNIQUE INDEX idx_mv_people_stats_person ON mv_people_stats(person_id);

CREATE MATERIALIZED VIEW mv_team_stats AS
SELECT
    t.id AS team_id,
    t.name AS team_name,
    t.color AS team_color,
    COALESCE(SUM(a.points), 0) AS total_points,
    COUNT(DISTINCT a.person_id) AS active_members,
    COUNT(DISTINCT p.id) AS total_members
FROM teams t
LEFT JOIN people p ON p.team_id = t.id
LEFT JOIN activities a ON a.team_id = t.id
GROUP BY t.id, t.name, t.color;

CREATE UNIQUE INDEX idx_mv_team_stats_team ON mv_team_stats(team_id);

-- ============================================================
-- 5. FUNCTION TO REFRESH MATERIALIZED VIEWS
-- ============================================================

CREATE OR REPLACE FUNCTION refresh_stats_views()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_people_stats;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_team_stats;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Refresh on activity changes
CREATE TRIGGER trg_refresh_stats_on_activity
AFTER INSERT OR UPDATE OR DELETE ON activities
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_stats_views();

-- Refresh on people changes (team switch, new user)
CREATE TRIGGER trg_refresh_stats_on_people
AFTER INSERT OR UPDATE OR DELETE ON people
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_stats_views();

-- ============================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Admin check function (SECURITY DEFINER bypasses RLS to avoid recursion)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM people WHERE id = auth.uid() AND is_admin = true
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE people ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- App config: everyone reads, only admins write
CREATE POLICY "Anyone can read config" ON app_config
    FOR SELECT USING (true);
CREATE POLICY "Admins can manage config" ON app_config
    FOR ALL USING (is_admin());

-- Teams: everyone reads, only admins write
CREATE POLICY "Anyone can read teams" ON teams
    FOR SELECT USING (true);
CREATE POLICY "Admins can manage teams" ON teams
    FOR ALL USING (is_admin());

-- Activity types: everyone reads, only admins write
CREATE POLICY "Anyone can read activity types" ON activity_types
    FOR SELECT USING (true);
CREATE POLICY "Admins can manage activity types" ON activity_types
    FOR ALL USING (is_admin());

-- People: everyone reads, users manage own, admins manage all
CREATE POLICY "Anyone can read people" ON people
    FOR SELECT USING (true);
CREATE POLICY "Users can insert own profile" ON people
    FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "Users can update own profile" ON people
    FOR UPDATE USING (id = auth.uid() OR is_admin());
CREATE POLICY "Admins can manage people" ON people
    FOR DELETE USING (is_admin());

-- Activities: everyone reads, users manage own, admins manage all
CREATE POLICY "Anyone can read activities" ON activities
    FOR SELECT USING (true);
CREATE POLICY "Users can insert own activities" ON activities
    FOR INSERT WITH CHECK (person_id = auth.uid());
CREATE POLICY "Users can update own activities" ON activities
    FOR UPDATE USING (person_id = auth.uid() OR is_admin());
CREATE POLICY "Users can delete own activities" ON activities
    FOR DELETE USING (person_id = auth.uid() OR is_admin());

-- ============================================================
-- 7. SEED DATA
-- ============================================================

-- Default app configuration
INSERT INTO app_config (key, value) VALUES
    ('inactive_days_threshold', '7'),
    ('inactive_percentile_threshold', '25');

-- Default teams
INSERT INTO teams (name, color) VALUES
    ('Niebieski Zespol', '#3B82F6'),
    ('Czerwony Zespol', '#EF4444');

-- Default activity types (from existing multipliers)
INSERT INTO activity_types (name, multiplier, icon) VALUES
    ('Bieganie', 2.0, 'running'),
    ('Spacer', 1.6, 'footprints'),
    ('Rolki', 1.4, 'disc'),
    ('Rower', 1.25, 'bike'),
    ('Plywanie', 3.0, 'waves');

-- ============================================================
-- 8. ENABLE REALTIME
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE activities;
ALTER PUBLICATION supabase_realtime ADD TABLE people;
ALTER PUBLICATION supabase_realtime ADD TABLE teams;

-- ============================================================
-- DONE! Now go to Supabase Dashboard and:
-- 1. Run this SQL in the SQL Editor
-- 2. Verify tables in Table Editor
-- 3. Make sure the 'distance_proofs' storage bucket exists
-- ============================================================
