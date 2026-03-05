# Propozycje zmian i nowych funkcjonalnosci

## Status implementacji

| # | Sugestia | Status |
|---|---------|--------|
| 1 | Toast notifications zamiast alert() | DONE |
| 2 | Loading states na przyciskach async | DONE |
| 3 | Skeleton loading zamiast spinnera | DONE |
| 4 | Confirm dialog (AlertDialog) zamiast confirm() | DONE |
| 5 | Empty state dla tabeli zespolu (loading vs empty) | DONE |
| 6 | Responsywnosc galerii + lazy loading | DONE |
| 7 | Blokada distance bez wybranego zespolu | DONE |
| 8 | Historia aktywnosci | DONE |
| 9 | Usuwanie wpisow dystansu | DONE |
| 10 | Realtime updates (Supabase Realtime) | DONE |
| 11 | Sortowanie tabeli zespolu | DONE |
| 12 | Walidacja hasla przy rejestracji | DONE |
| 13 | Podzial useTeamData na mniejsze hooki | DONE |
| 14 | Dropdown zespolu z teamConfig | DONE |
| 15 | Upload proof do konkretnego wpisu | DONE |
| 16 | Obsluga bledow sieciowych | DONE |
| 17 | Leaderboard na stronie glownej | DONE |
| 18 | Cele zespolowe / indywidualne | TODO |
| 19 | Streaki | DONE |
| 20 | Export danych (CSV) | DONE |
| 21 | Admin panel (frontend) | DONE |
| 22 | Peer review aktywnosci | TODO |

---

## Szczegoly implementacji

### S10: Realtime
Subskrypcja na tabele `Distance` w TeamPage — tabela zespolu auto-odswiezana po zmianach.
Wymaga wlaczenia Realtime w Supabase dashboard (Project Settings > API > Realtime > Enable for table `Distance`).

### S21: Admin panel — co zostalo zrobione
- Hook `useAdmin.ts` sprawdza kolumne `is_admin` w tabeli `People`
- Przycisk "-" (SubtractDistance) widoczny tylko dla adminow
- Link do Randomizera widoczny tylko dla adminow
- **Wymaga:** dodania kolumny `is_admin` (boolean, default false) do tabeli `People` w Supabase

### S19: Streaki
Liczenie unikalnych dni z aktywnoscia wstecz od dzisiaj. Wyswietlane w profilu z ikona ognia.
Streak liczy sie od dzisiaj — jesli dzisiaj nie bylo aktywnosci, streak = 0.

---

## Pozostale propozycje (nieimplementowane)

### 18. Cele zespolowe / indywidualne
Mozliwosc ustawienia celu (np. "500 pts do konca tygodnia") z progress barem.
- Nowa tabela `Goals` (person, team, target, deadline)
- Widget w profilu z postepem

### 22. Potwierdzenie aktywnosci (peer review)
Dodana aktywnosc wymaga zatwierdzenia przez kolege z zespolu zanim doliczy sie do wyniku.
- Nowa kolumna `verified` w `Distance`
- Powiadomienia dla czlonkow zespolu
- Panel weryfikacji

---

## Wymagane zmiany w Supabase (backend)

1. **Kolumna `is_admin`** w tabeli `People` — `ALTER TABLE "People" ADD COLUMN is_admin boolean DEFAULT false;`
2. **Realtime** — wlacz Realtime dla tabeli `Distance` w Supabase Dashboard
3. **RLS Policies** (opcjonalne) — ograniczenie kto moze uruchamiac Randomizer / SubtractDistance na poziomie bazy danych
