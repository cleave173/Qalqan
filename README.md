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

Telegram setup:

1. Create a bot in Telegram through `@BotFather` and copy the token.
2. Put the token into the project `.env` file as `TELEGRAM_BOT_TOKEN=...`.
3. The child must open the bot and press Start once.
4. Get the child's `chat_id` through `https://api.telegram.org/bot<token>/getUpdates` after that Start message.
5. Enter that `chat_id` in the Qalqan app field `Telegram chat_id`.

The backend does not run a long-polling bot process. It sends alerts through Telegram Bot API when `/qalqan/alerts` is called. The alert includes an inline button with `tel:<parent_phone>` so the child can quickly call the parent.

Run locally:

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Run with Docker:

```bash
cp .env.example .env
docker compose up -d db api
```

Main Qalqan endpoints:

- `GET /qalqan/profile`
- `PUT /qalqan/profile`
- `POST /qalqan/subscription/checkout`
- `POST /qalqan/parents`
- `DELETE /qalqan/parents/{parent_id}`
- `POST /qalqan/alerts`

Subscription MVP:

- New child accounts start with a 20-day `trial`.
- `personal` allows 1 parent phone.
- `family` allows up to 4 parent phones.
- `subscription_period` can be `monthly` or `yearly`.
- Real payments are not connected in the MVP. The app uses a demo checkout flow and stores the resulting active subscription in PostgreSQL.
- Trial and paid subscriptions have expiration dates. Expired subscriptions are blocked until demo checkout is completed again.
- Downgrading from `family` to `personal` is blocked when more than 1 parent phone is already bound.

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
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.10.12:8000
```

Debug APK output:

```text
frontend/build/app/outputs/flutter-apk/app-debug.apk
```

The Flutter project is Android-focused for this MVP.

Physical Android checklist:

1. Keep the phone and Mac on the same Wi-Fi network.
2. Start backend with `docker compose up -d db api`.
3. Check the Mac LAN IP with `ifconfig | grep "inet "`.
4. Build or run the app with `--dart-define=API_BASE_URL=http://<MAC_IP>:8000`.
5. Install `frontend/build/app/outputs/flutter-apk/app-debug.apk` on the phone.
6. Allow Phone, Microphone, SMS receive/read/send permissions on first launch.
7. Open Android Settings -> Accessibility and enable Qalqan service.
8. In Telegram, the child must open `@qalqan1_bot` and press Start.
9. Put the child's Telegram `chat_id` into the app.
10. Use Family when more than one parent phone must be bound.

## Notes

- Target SDK is set to `29` for the requested Android 9-10 compatibility profile.
- `minSdk` is `24`; `targetSdk` is `29` for the requested Android 9-10 compatibility profile.
- Physical phones cannot reach the Mac backend through `10.0.2.2`; that address is only for Android emulators.
- Speech-to-text during a phone call depends on Android device, firmware and audio routing behavior. The critical SMS path and direct SMS alert path are native and do not depend on internet access.
