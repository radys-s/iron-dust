# Iron Dust — roadmap (Fáze 6+)

- **Etapa 2 — Správa + UI.** Celoobrazovková Správa (vlastní tab bar, scrim), hotový Přehled; Obchod, Sídla, Technologie, Kronika jako placeholdery, pak postupně plnit. Horizontální lišta staveb, spodní info panel dlaždice, Příručka, výběr módu označí nehotové věci „připravuje se".
- **Etapa 3 — hloubka ekonomiky.** Tvrdý start (~150 zlata, pop ~40), výnos jen z vlastněné půdy, `Terrain.FOREST`, 9 surovin, řetězce (dřevo→prkna, ruda+uhlí→železo, železo+prkna→nářadí), pravidla stavění, sloty sídel, železnice stavěná hráčem (flood fill od města, výhra = okraj mapy) + limit tahů, záložka Výroba. Opravit `build()`/`research()` obcházející game-over guard.
- **Etapa 4 — módy, tutoriál, adaptivní AI.** `Ruleset` Beginner/Advanced, sandbox tutoriál, profil hráče → adaptace H-V AI (deterministická, později nahraditelná RL), SaveGame v4.
- Později: pergamenový lore koncept.

Pracovní režim: implementace → reálné ověření (testy + screenshot) → review → oprava → commit + push.
