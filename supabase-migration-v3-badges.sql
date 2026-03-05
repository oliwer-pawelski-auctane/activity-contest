-- ============================================================
-- Activity Contest App - Migration V3
-- New badges (run AFTER v2 migration)
-- ============================================================

INSERT INTO badges (key, name, description, icon) VALUES
    ('early_bird', 'Wczesny ptaszek', 'Dodaj aktywność przed 6:00', 'sunrise'),
    ('night_owl', 'Nocny marek', 'Dodaj aktywność po 23:00', 'moon'),
    ('variety_all', 'Renesansowy', 'Wypróbuj wszystkie typy aktywności', 'palette'),
    ('comeback', 'Comeback', 'Wróć po 21+ dniach przerwy', 'rotate-ccw'),
    ('marathon', 'Maratończyk', 'Pojedyncza aktywność warta 10+ pkt', 'rocket'),
    ('star_proof', 'Gwiazda', 'Zdobądź 10 reakcji na swoje dowody', 'sparkles'),
    ('motivator', 'Motywator', 'Daj 10 reakcji na dowody innych', 'heart-handshake'),
    ('collector', 'Kolekcjoner', 'Zdobądź 5 różnych odznak', 'album'),
    ('proof_50', 'Kronikarz', 'Dodaj 50 dowodów aktywności', 'film')
ON CONFLICT (key) DO NOTHING;
