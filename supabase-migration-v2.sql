-- ============================================================
-- Activity Contest App - Migration V2
-- New features: badges, reactions, team change log
-- Run AFTER the initial migration
-- ============================================================

-- ============================================================
-- 1. BADGES SYSTEM
-- ============================================================

CREATE TABLE IF NOT EXISTS badges (
    id SERIAL PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT DEFAULT 'award',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_badges (
    id SERIAL PRIMARY KEY,
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    badge_id INT NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(person_id, badge_id)
);

CREATE INDEX idx_user_badges_person ON user_badges(person_id);

-- Seed badges
INSERT INTO badges (key, name, description, icon) VALUES
    ('first_activity', 'Pierwszy krok', 'Dodaj swoją pierwszą aktywność', 'footprints'),
    ('streak_3', 'Regularność', '3 dni aktywności z rzędu', 'flame'),
    ('streak_7', 'Tydzień mocy', '7 dni aktywności z rzędu', 'zap'),
    ('streak_14', 'Niezłomny', '14 dni aktywności z rzędu', 'shield'),
    ('streak_30', 'Mistrz dyscypliny', '30 dni aktywności z rzędu', 'crown'),
    ('points_10', 'Początkujący', 'Zdobądź 10 punktów', 'star'),
    ('points_50', 'Aktywista', 'Zdobądź 50 punktów', 'trophy'),
    ('points_100', 'Centurion', 'Zdobądź 100 punktów', 'medal'),
    ('points_500', 'Legenda', 'Zdobądź 500 punktów', 'gem'),
    ('proof_5', 'Dokumentalista', 'Dodaj 5 dowodów aktywności', 'camera'),
    ('proof_20', 'Paparazzo', 'Dodaj 20 dowodów aktywności', 'image'),
    ('variety_3', 'Wszechstronny', 'Wypróbuj 3 różne typy aktywności', 'shuffle'),
    ('team_player', 'Gracz zespołowy', 'Dołącz do zespołu', 'users')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 2. PROOF REACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS proof_reactions (
    id SERIAL PRIMARY KEY,
    activity_id INT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL DEFAULT '👍',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(activity_id, person_id, emoji)
);

CREATE INDEX idx_proof_reactions_activity ON proof_reactions(activity_id);

-- ============================================================
-- 3. TEAM CHANGE LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS team_changes (
    id SERIAL PRIMARY KEY,
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    old_team_id INT REFERENCES teams(id) ON DELETE SET NULL,
    new_team_id INT REFERENCES teams(id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_team_changes_person ON team_changes(person_id);
CREATE INDEX idx_team_changes_date ON team_changes(changed_at);

-- Auto-log team changes via trigger
CREATE OR REPLACE FUNCTION log_team_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.team_id IS DISTINCT FROM NEW.team_id THEN
        INSERT INTO team_changes (person_id, old_team_id, new_team_id)
        VALUES (NEW.id, OLD.team_id, NEW.team_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_log_team_change
AFTER UPDATE ON people
FOR EACH ROW
EXECUTE FUNCTION log_team_change();

-- ============================================================
-- 4. RLS FOR NEW TABLES
-- ============================================================

ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE proof_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_changes ENABLE ROW LEVEL SECURITY;

-- Badges: everyone reads
CREATE POLICY "Anyone can read badges" ON badges FOR SELECT USING (true);
CREATE POLICY "Admins manage badges" ON badges FOR ALL USING (is_admin());

-- User badges: everyone reads, system inserts
CREATE POLICY "Anyone can read user badges" ON user_badges FOR SELECT USING (true);
CREATE POLICY "Users can earn badges" ON user_badges FOR INSERT WITH CHECK (person_id = auth.uid());
CREATE POLICY "Admins manage user badges" ON user_badges FOR ALL USING (is_admin());

-- Proof reactions: everyone reads, users manage own
CREATE POLICY "Anyone can read reactions" ON proof_reactions FOR SELECT USING (true);
CREATE POLICY "Users can add reactions" ON proof_reactions FOR INSERT WITH CHECK (person_id = auth.uid());
CREATE POLICY "Users can remove own reactions" ON proof_reactions FOR DELETE USING (person_id = auth.uid());

-- Team changes: everyone reads
CREATE POLICY "Anyone can read team changes" ON team_changes FOR SELECT USING (true);

-- ============================================================
-- 5. ENABLE REALTIME FOR NEW TABLES
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE proof_reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE user_badges;
