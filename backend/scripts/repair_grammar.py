import asyncio
import re
import os
import sys

# Add parent directory to path so we can import app modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app.models import Item, Lesson, Category
from sqlalchemy import select

async def repair_grammar_smart():
    print("🚀 Starting SMART Grammar data repair (v5)...")
    async with SessionLocal() as db:
        # 1. Fetch Grammar categories
        cat_stmt = select(Category)
        cat_res = await db.execute(cat_stmt)
        categories = cat_res.scalars().all()
        
        grammar_cat_ids = [c.id for c in categories if c.name_translations.get('en') == 'Grammar']
        if not grammar_cat_ids:
            print("❌ No Grammar categories found. Check your data.")
            return

        # 2. Fetch all items for these categories
        stmt = (
            select(Item)
            .join(Lesson, Item.lesson_id == Lesson.id)
            .where(Lesson.category_id.in_(grammar_cat_ids))
        )
        
        result = await db.execute(stmt)
        items = result.scalars().all()
        
        repaired_count = 0
        separator_pattern = re.compile(r'[=—–:-]')
        
        for item in items:
            ru_val = item.translations.get('ru', '')
            
            # Type A: Separator-based ("I — я")
            if separator_pattern.search(ru_val):
                parts = separator_pattern.split(ru_val)
                if len(parts) >= 2:
                    en_part = parts[0].strip()
                    ru_part = parts[1].strip()
                    
                    item.text_content = en_part
                    
                    new_trans = dict(item.translations)
                    new_trans['ru'] = ru_part
                    
                    # Also try to clean up 'kk' if it exists and follows the same pattern
                    kk_val = item.translations.get('kk', '')
                    if separator_pattern.search(kk_val):
                        kk_parts = separator_pattern.split(kk_val)
                        if len(kk_parts) >= 2:
                            new_trans['kk'] = kk_parts[1].strip()
                    
                    item.translations = new_trans
                    repaired_count += 1
            
            # Type B: Rule-based ("You/We/They are") - first slot IS the answer
            # We identify this if text_content is still null/empty and NO separator was matched
            elif not item.text_content or item.text_content.strip() == "":
                # The prompt should be the description!
                description = item.extra_data_json.get('description', {})
                if isinstance(description, dict) and description.get('ru'):
                    # The English answer is currently stored in translations['ru'] by the buggy old seed
                    item.text_content = ru_val
                    # The prompt card should show the Russian/Kazakh description
                    item.translations = description
                    repaired_count += 1
                    
        await db.commit()
        print(f"✅ Successfully smart-repaired {repaired_count} items!")

if __name__ == "__main__":
    asyncio.run(repair_grammar_smart())
