"""Seed script – populates phases, categories, lessons, and items.

Run with: docker exec -it pry_api python -m scripts.seed
Or locally: python -m scripts.seed

Data source: 3600 curated items based on the Oxford 3000 word list,
organized by CEFR micro-level (A1.1 → A1.2 → A1.3).
"""
import asyncio
import json
import sys
import os

# Add parent directory to path so we can import app modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import engine, SessionLocal, Base
from app.models import Phase, Category, Lesson, Item

# ── Import curated data ──────────────────────────────────────────────────
from scripts.data.vocab_data import VOCAB_PHASE_1, VOCAB_PHASE_2, VOCAB_PHASE_3
from scripts.data.grammar_p1 import GRAMMAR_PHASE_1
from scripts.data.grammar_p2 import GRAMMAR_PHASE_2
from scripts.data.grammar_p3 import GRAMMAR_PHASE_3
from scripts.data.sentences_p1 import SENTENCES_PHASE_1
from scripts.data.sentences_p2 import SENTENCES_PHASE_2
from scripts.data.sentences_p3 import SENTENCES_PHASE_3
from scripts.data.vocab_a2_b1 import VOCAB_PHASE_4, VOCAB_PHASE_5
from scripts.data.grammar_p4 import GRAMMAR_PHASE_4
from scripts.data.grammar_p5 import GRAMMAR_PHASE_5
from scripts.data.sentences_p4 import SENTENCES_PHASE_4
from scripts.data.sentences_p5 import SENTENCES_PHASE_5
from scripts.data.vocab_b2 import VOCAB_PHASE_6
from scripts.data.grammar_p6 import GRAMMAR_PHASE_6
from scripts.data.sentences_p6 import SENTENCES_PHASE_6
from scripts.data.vocab_c1_c2 import VOCAB_PHASE_7, VOCAB_PHASE_8
from scripts.data.grammar_p7 import GRAMMAR_PHASE_7
from scripts.data.sentences_p7 import SENTENCES_PHASE_7
from scripts.data.grammar_p8 import GRAMMAR_PHASE_8
from scripts.data.sentences_p8 import SENTENCES_PHASE_8


# ═══════════════════════════════════════════════════════════════════════════
# Map phase_id → data dictionaries
# ═══════════════════════════════════════════════════════════════════════════
VOCAB_DATA = {1: VOCAB_PHASE_1, 2: VOCAB_PHASE_2, 3: VOCAB_PHASE_3, 4: VOCAB_PHASE_4, 5: VOCAB_PHASE_5, 6: VOCAB_PHASE_6, 7: VOCAB_PHASE_7, 8: VOCAB_PHASE_8}
GRAMMAR_DATA = {1: GRAMMAR_PHASE_1, 2: GRAMMAR_PHASE_2, 3: GRAMMAR_PHASE_3, 4: GRAMMAR_PHASE_4, 5: GRAMMAR_PHASE_5, 6: GRAMMAR_PHASE_6, 7: GRAMMAR_PHASE_7, 8: GRAMMAR_PHASE_8}
SENTENCE_DATA = {1: SENTENCES_PHASE_1, 2: SENTENCES_PHASE_2, 3: SENTENCES_PHASE_3, 4: SENTENCES_PHASE_4, 5: SENTENCES_PHASE_5, 6: SENTENCES_PHASE_6, 7: SENTENCES_PHASE_7, 8: SENTENCES_PHASE_8}

PHASES = [
    {"id": 1, "title_translations": {"en": "Phase 1: Foundation", "ru": "Фаза 1: Основы", "kk": "1-фаза: Негіздер"}, "internal_cefr_level": "A1.1", "required_lessons_to_pass": 80},
    {"id": 2, "title_translations": {"en": "Phase 2: Development", "ru": "Фаза 2: Развитие", "kk": "2-фаза: Дамыту"}, "internal_cefr_level": "A1.2", "required_lessons_to_pass": 80},
    {"id": 3, "title_translations": {"en": "Phase 3: Reinforcement", "ru": "Фаза 3: Укрепление", "kk": "3-фаза: Қалыптастыру"}, "internal_cefr_level": "A1.3", "required_lessons_to_pass": 80},
    {"id": 4, "title_translations": {"en": "Phase 4: Expansion", "ru": "Фаза 4: Расширение", "kk": "4-фаза: Кеңейту"}, "internal_cefr_level": "A2", "required_lessons_to_pass": 80},
    {"id": 5, "title_translations": {"en": "Phase 5: Practice", "ru": "Фаза 5: Практика", "kk": "5-фаза: Тәжірибе"}, "internal_cefr_level": "B1", "required_lessons_to_pass": 80},
    {"id": 6, "title_translations": {"en": "Phase 6: Confidence", "ru": "Фаза 6: Уверенность", "kk": "6-фаза: Сенімділік"}, "internal_cefr_level": "B2", "required_lessons_to_pass": 80},
    {"id": 7, "title_translations": {"en": "Phase 7: Mastery I", "ru": "Фаза 7: Мастерство I", "kk": "7-фаза: Шеберлік I"}, "internal_cefr_level": "C1", "required_lessons_to_pass": 120},
    {"id": 8, "title_translations": {"en": "Phase 8: Mastery II", "ru": "Фаза 8: Мастерство II", "kk": "8-фаза: Шеберлік II"}, "internal_cefr_level": "C2", "required_lessons_to_pass": 120},
]

CATEGORIES_PER_PHASE = [
    {"name_translations": {"en": "Vocabulary", "ru": "Слова", "kk": "Сөздік"}, "icon_name": "book-02"},
    {"name_translations": {"en": "Grammar", "ru": "Грамматика", "kk": "Грамматика"}, "icon_name": "puzzle"},
    {"name_translations": {"en": "Listening", "ru": "Аудирование", "kk": "Тыңдалым"}, "icon_name": "headphones"},
    {"name_translations": {"en": "Speaking", "ru": "Говорение", "kk": "Айтылым"}, "icon_name": "mic-01"},
]


async def seed():
    """Main seed function."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with SessionLocal() as db:
        # Fetch existing seeded phases so we only insert missing ones
        from sqlalchemy import select
        existing_phases_res = await db.execute(select(Phase.id))
        existing_phase_ids = [row[0] for row in existing_phases_res.all()]

        phases_to_seed = [p for p in PHASES if p["id"] not in existing_phase_ids]

        if not phases_to_seed:
            print("Database already has all phases seeded. Skipping.")
            return

        print(f"🌱 Seeding {len(phases_to_seed)} new phases with Oxford data...")

        # ── Phases ────────────────────────────────────────────────
        for p_data in phases_to_seed:
            phase = Phase(**p_data)
            db.add(phase)
        await db.flush()
        print(f"  ✅ {len(phases_to_seed)} phases created")

        # ── Categories, Lessons, Items ────────────────────────────
        total_lessons = 0
        total_items = 0

        for phase_data in phases_to_seed:
            phase_id = phase_data["id"]

            vocab_dict = VOCAB_DATA[phase_id]
            grammar_dict = GRAMMAR_DATA[phase_id]
            sentence_dict = SENTENCE_DATA[phase_id]

            for cat_data in CATEGORIES_PER_PHASE:
                category = Category(
                    phase_id=phase_id,
                    name_translations=cat_data["name_translations"],
                    icon_name=cat_data["icon_name"],
                )
                db.add(category)
                await db.flush()

                cat_name_en = cat_data["name_translations"]["en"]

                # Pick the right topic list
                if cat_name_en == "Vocabulary":
                    topic_dict = vocab_dict
                elif cat_name_en == "Grammar":
                    topic_dict = grammar_dict
                else:  # Listening & Speaking share sentence data
                    topic_dict = sentence_dict

                for order_idx, topic_name in enumerate(topic_dict.keys(), start=1):
                    # Source topic keys are typically in Russian — keep them
                    # for ru/kk and use the same string as a fallback for en.
                    # When better translations exist (dict-shaped key), they
                    # will be picked up by future curated data sets.
                    topic_translations = {
                        "ru": topic_name,
                        "kk": topic_name,
                        "en": topic_name,
                    }
                    lesson = Lesson(
                        category_id=category.id,
                        topic_translations=topic_translations,
                        order_index=order_idx,
                    )
                    db.add(lesson)
                    await db.flush()
                    total_lessons += 1

                    topic_items = topic_dict[topic_name]

                    if cat_name_en == "Vocabulary":
                        for text, trans_val in topic_items:
                            # Handle both old string format and new dict format
                            if isinstance(trans_val, str):
                                translations_dict = {"ru": trans_val, "kk": f"{trans_val}_KZ"} # Placeholder for now
                            else:
                                translations_dict = trans_val

                            item = Item(
                                lesson_id=lesson.id,
                                item_type="word",
                                text_content=text,
                                translations=translations_dict,
                            )
                            db.add(item)
                            total_items += 1

                    elif cat_name_en == "Grammar":
                        import re
                        separator_pattern = re.compile(r'[=—–:-]')
                        for rule_val, desc_val, extra in topic_items:
                            text_content = ""
                            rule_dict = {}
                            if isinstance(rule_val, str):
                                if separator_pattern.search(rule_val):
                                    parts = separator_pattern.split(rule_val)
                                    if len(parts) >= 2:
                                        text_content = parts[0].strip()
                                        rule_val = parts[1].strip()
                                    rule_dict = {"ru": rule_val, "kk": f"{rule_val}_KZ"}
                                else:
                                    # If no separator, the RULE itself is the answer, and DESC is the prompt
                                    text_content = rule_val
                                    rule_dict = {"ru": desc_val, "kk": f"{desc_val}_KZ"}
                                
                                desc_dict = {"ru": desc_val, "kk": f"{desc_val}_KZ"}
                            else:
                                rule_dict = rule_val
                                desc_dict = desc_val
                                text_content = rule_dict.get("en", "")

                            item = Item(
                                lesson_id=lesson.id,
                                item_type="grammar_rule",
                                text_content=text_content,
                                translations=rule_dict,
                                extra_data_json={"description": desc_dict, **extra},
                            )
                            db.add(item)
                            total_items += 1

                    else:  # Listening & Speaking → sentences
                        for text, trans_val in topic_items:
                            if isinstance(trans_val, str):
                                translations_dict = {"ru": trans_val, "kk": f"{trans_val}_KZ"}
                            else:
                                translations_dict = trans_val

                            item = Item(
                                lesson_id=lesson.id,
                                item_type="sentence",
                                text_content=text,
                                translations=translations_dict,
                            )
                            db.add(item)
                            total_items += 1

        await db.commit()
        print(f"  ✅ {total_lessons} lessons created")
        print(f"  ✅ {total_items} items created")
        print("🎉 Seeding complete!")


if __name__ == "__main__":
    asyncio.run(seed())
