# Автоматично качване в Google Play — настройка

Това, което Claude може да прави сам после:
```bash
bash tools/release-to-play.sh internal     # билдва AAB + качва в Internal testing
bash tools/release-to-play.sh alpha        # ... в Closed testing (default closed track = "alpha")
```
(Или директно качване на вече билднат AAB: `python tools/play_upload.py --aab <път> --track alpha --service-account <json>`.)

## Единствената стъпка, която е ТВОЯ (еднократно) — service account JSON

Google не позволява на скрипт да качва, без оторизиран „service account". Създава се веднъж:

1. **Play Console → Setup → API access** (или „Настройки → API достъп").
2. Натисни **Create new service account** → следва линка към **Google Cloud Console**.
3. В Google Cloud: **Create service account** (име напр. `play-upload`) → Create and continue → Done.
4. На service account-а: **Keys → Add key → Create new key → JSON** → сваля се `.json` файл.
5. Запази файла като:  `C:\Users\Admin\keys\play-service-account.json`
   (тази папка вече е извън репото и е в .gitignore — ключът няма да изтече).
6. Върни се в **Play Console → API access → Grant access** за новия акаунт →
   роля минимум **„Release to testing tracks"** (или Admin за тестовете) → Invite/Apply.
7. Готово. Кажи на Claude „качи в тестване" и той пуска `release-to-play.sh`.

## Бележки
- **Първото качване по веригата трябва да е минало през конзолата.** За `com.ivoexp.habits`
  Internal testing вече е публикуван (v1.0.0), значи пакетът съществува — API качванията ще минават.
- За **Closed testing** трекът обикновено има собствено име в конзолата. Ако не е „alpha",
  подай точното име: `bash tools/release-to-play.sh "име-на-трека"`.
- Подписването използва `android/key.properties` + `C:\Users\Admin\keys\upload.jks` (вече налични).
- Алтернатива (GitHub Actions) остава налична през `.github/workflows/release.yml` ако някога
  предпочетеш облачен билд — нужни са 5 GitHub secrets вместо локалния JSON.
