# PRY — Imperial Refactor (changelog)

This document captures the breaking schema/API changes shipped together
with the new "Imperial Scroll" visual identity and the database/backend
hygiene fixes.

---

## 1. Database — breaking changes

The schema is incompatible with the previous version. The project uses
`Base.metadata.create_all` (no Alembic), so the simplest path is to drop
the database and re-seed.

### What changed

| Area | Before | After |
|---|---|---|
| Foreign-key columns | unindexed | `index=True` on every FK + on `next_review_date` |
| `lessons.topic_name` | single `String(200)` | `topic_translations` JSON `{en, ru, kk}` |
| `users.match_highscore` / `sprint_highscore` | denormalised columns | new `game_scores` table (one row per `(user_id, game_type)`) |
| `user_learned_items` | only `mistakes_count`, `next_review_date` | full SM-2 set: `correct_streak`, `ease_factor`, `interval_days`, `last_reviewed_date`, `next_review_date` + `UniqueConstraint(user_id, item_id)` |
| `placement.evaluate` | hard-capped to phase 3 | dynamic cap = `MAX(phases.id)` |
| `list_categories` | N+1 (1 + 2N queries) | single GROUP BY query |
| Routers | mixed `await db.commit()` + dependency commit | always rely on `get_db` to commit |

### How to apply

From the project root:

```bash
# 1. stop & wipe Postgres
docker-compose down -v

# 2. start fresh
docker-compose up -d db

# 3. start the API (it will run create_all on startup)
docker-compose up -d api

# 4. reseed
docker exec -it pry_api python -m scripts.seed
```

If you do not use docker locally, just drop and recreate the Postgres
database, then run `python -m scripts.seed` against it.

> **Note**: existing user accounts and progress will be lost. This is
> expected for a thesis project that has not yet shipped to real users.

---

## 2. New API endpoints (spaced repetition)

- `GET /progress/srs/due?limit=30` — items due for review for the
  current user. Returns `[{item_id, text_content, translations,
  item_type, correct_streak, ease_factor, interval_days,
  next_review_date}]`.
- `POST /progress/srs/review` body `{item_id, quality}` where
  `quality` is the SM-2 grade in `[0..5]`. Updates the user's SRS
  metadata for that item using a SuperMemo-2 lite formula.

---

## 3. Frontend — design system

A new design system replaces the old claymorphism look:

- **Theme name**: `Imperial Scroll`
- **Palette**: parchment ivory, deep crimson (cape), antique gold (trim),
  steel navy (armor), jade green (success).
- **Typography**: `Cormorant Garamond` for headings + serif accents,
  `Nunito` for body text.
- **Brand mark**: an original geometric "imperial helm" emblem
  (`AppLogo`, in `core/widgets/app_logo.dart`) — drawn in a
  `CustomPainter` from primitives, no external/copyrighted asset.

Legacy color names (`primaryBlue`, `accentOchre`, `cardShadowDark`,
etc.) are kept as aliases on `AppTheme` so screens that have not been
re-skinned yet still compile and render with the new palette.

---

## 4. Notes

- Topic names are now multilingual; until curated translations are
  available, `seed.py` mirrors the source string into all three
  language slots.
- `UserResponse.match_highscore` / `sprint_highscore` were removed —
  use `UserResponse.game_scores["match"|"sprint"]` instead.
