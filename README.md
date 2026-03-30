# Mood Tracker

Flutter で作っている個人用の mood tracker アプリです。  
手入力の daily log と Fitbit 由来の wearable data を同じアプリ内で見られる、軽めの MVP を目指しています。

## Current Scope

- `Home`
  - 今日の記録状況を表示
  - `Log today` / `Edit today's log`
  - Fitbit 接続状態の簡易表示
- `Trends`
  - 手入力データの推移
  - Fitbit の `Sleep Duration` / `Resting Heart Rate` の推移
  - `7D / 30D / 3M / 1Y` の期間切替
- `History`
  - 月間カレンダー表示
  - Manual data / Wearable data の有無を別ドットで表示
  - 日付ごとの詳細表示
- `Settings`
  - Fitbit 接続
  - Fitbit 同期
  - Fitbit backfill
  - ローカルデータ初期化

## Daily Log

手入力で扱う項目は次の 5 つです。

- Mood
- Motivation
- Fatigue
- Hunger
- Sweet Craving

各項目は `1` から `5` のスケールで入力し、任意メモを添えられます。

## Fitbit Integration

現状の Fitbit 連携は MVP 段階です。

- custom URL scheme: `moodtracker://fitbit-callback`
- callback 後に authorization code exchange を実行
- access token / refresh token はローカル保存
- 手動 sync で当日分の Fitbit データを取得
- backfill で直近 `30` 日または `90` 日を取得

扱っている Fitbit 指標は次の 2 つだけです。

- `sleep_duration_min`
- `resting_heart_rate_bpm`

## Local Storage

このアプリは現在ローカル保存ベースです。

- Daily log
  - `SharedPreferences`
  - `1 log date = 1 entry`
- Wearable daily metrics
  - `SharedPreferences`
  - 日付ごとの日次 record
- Fitbit connection
  - `SharedPreferences`
- Fitbit OAuth token
  - `SharedPreferences`

`Settings > Danger Zone > Reset local app data` で、アプリ内のローカル保存だけを削除できます。  
Fitbit 側のクラウドデータは削除しません。

## Getting Started

### Requirements

- Flutter SDK
- Android Studio または Android 実機開発環境

### Install

```bash
flutter pub get
```

### Run

最小実行:

```bash
flutter run
```

Fitbit OAuth を使う場合:

```bash
flutter run --dart-define=FITBIT_CLIENT_SECRET=YOUR_CLIENT_SECRET
```

`env.json` を使ってまとめて渡す場合:

```bash
flutter run --dart-define-from-file=env.json
```

### Build

release APK を作る例:

```bash
flutter build apk --release --dart-define-from-file=env.json
```

作成した APK を端末へ入れる例:

```bash
flutter install
```

補足:

- `FITBIT_CLIENT_ID` は現在 [fitbit_config.dart](./lib/features/wearables/config/fitbit_config.dart) にデフォルト値があります
- `FITBIT_CLIENT_SECRET` は `dart-define` で渡す前提です

## Fitbit Flow

1. `Settings` を開く
2. `Connect Fitbit` を押す
3. ブラウザで Fitbit 認可を完了する
4. `moodtracker://fitbit-callback` でアプリへ戻る
5. token exchange が成功すると接続済みになる
6. 接続後は `Sync Fitbit` で当日分を取得できる
7. 必要なら `Backfill last 30 days` / `Backfill last 90 days` で過去データをまとめて取得する

## Project Structure

```text
lib/
  app/
    app.dart
    settings_menu_button.dart
  features/
    daily_log/
    history/
    home/
    settings/
    trends/
    wearables/
  shared/
```

主要な役割:

- `lib/app/app.dart`
  - App shell
  - bottom navigation
  - 起動時データ読込
- `lib/features/daily_log/`
  - daily log 入力 UI
  - local repository
- `lib/features/history/`
  - カレンダー表示
  - 日別詳細
- `lib/features/trends/`
  - 手入力 / wearable の trend 表示
- `lib/features/settings/`
  - Fitbit 接続 UI
  - settings orchestration
- `lib/features/wearables/`
  - Fitbit OAuth
  - Fitbit API client
  - sync / callback / repository
- `lib/shared/`
  - 共通 date / format utility

## Notes

- Android 側では `INTERNET` permission を付与済みです
- Fitbit callback 用 deep link は Android / iOS の両方に設定済みです
- launcher icon の差し替え設定は `pubspec.yaml` に残っていますが、運用はまだ任意です
