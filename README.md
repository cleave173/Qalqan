# Qalqan MVP

Qalqan is an MVP for family antifraud protection. The Android app monitors an active phone call, detects suspicious speech triggers and critical SMS codes from banking/government senders, then alerts the child through two channels: FastAPI/Telegram and direct cellular SMS.

## Stack

- Flutter Android app
- Native Android Kotlin bridge for phone state, SMS receive and direct SMS send
- Python FastAPI backend
- PostgreSQL via SQLAlchemy async models
- Telegram Bot API for internet alerts

## MVP Features

- Subscription plans:
  - `personal`: one parent phone
  - `family`: up to four parent phones
- Parent binding limit enforced by FastAPI.
- Android permissions for phone state, microphone, SMS receive/read/send and accessibility service metadata.
- Call detection through `PHONE_STATE` / `OFFHOOK`.
- Speech trigger dictionary:
  - `каспи`, `kaspi`, `служба безопасности`, `код из смс`, `безопасный счет`, `перевод`, `попал в аварию`, `следователь`, `мвд`, `прокуратура`
- Critical SMS detection during an active call from:
  - `Kaspi.kz`, `Kaspi`, `1414`, `HalykBank`
- Code extraction with a numeric regular expression.
- Telegram alert with a quick call button.
- Direct emergency SMS fallback without internet.

## Backend

Environment variables:

```bash
DATABASE_URL=postgresql+asyncpg://qalqan_user:qalqan_secret@localhost:5432/qalqan_db
SECRET_KEY=change-me
TELEGRAM_BOT_TOKEN=123456:telegram-token
```

Run locally:

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Main Qalqan endpoints:

- `GET /qalqan/profile`
- `PUT /qalqan/profile`
- `POST /qalqan/parents`
- `DELETE /qalqan/parents/{parent_id}`
- `POST /qalqan/alerts`

All Qalqan endpoints use the existing Bearer JWT auth flow.

## Android App

Run/debug:

```bash
cd frontend
flutter pub get
flutter run
```

Build APK:

```bash
cd frontend
flutter build apk --debug
```

Debug APK output:

```text
frontend/build/app/outputs/flutter-apk/app-debug.apk
```

The Flutter project is Android-focused for this MVP.

## Notes

- Target SDK is set to `29` for the requested Android 9-10 compatibility profile.
- `minSdk` is `24`; `targetSdk` is `29` for the requested Android 9-10 compatibility profile.
- Speech-to-text during a phone call depends on Android device, firmware and audio routing behavior. The critical SMS path and direct SMS alert path are native and do not depend on internet access.
