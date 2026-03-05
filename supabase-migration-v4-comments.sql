-- ============================================================
-- Activity Contest App - Migration V4
-- New feature: proof comments
-- Run AFTER v2 migration
-- ============================================================

CREATE TABLE IF NOT EXISTS proof_comments (
    id SERIAL PRIMARY KEY,
    activity_id INT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_proof_comments_activity ON proof_comments(activity_id);

ALTER TABLE proof_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read comments" ON proof_comments FOR SELECT USING (true);
CREATE POLICY "Users can add comments" ON proof_comments FOR INSERT WITH CHECK (person_id = auth.uid());
CREATE POLICY "Users can delete own comments" ON proof_comments FOR DELETE USING (person_id = auth.uid());

ALTER PUBLICATION supabase_realtime ADD TABLE proof_comments;
