# Навици — DEVLOG

Newest first. (Handoff контекстът е в CLAUDE.md; тук са по-едрите технически решения / TODO.)

## TODO 1.4.14 — per-habit merge при облачен download
Текущият sync прилага облачния blob **whole-document** (`BackupService.apply` презаписва
целия `habits` низ + `history`, без merge) → при **concurrent** запис от друго устройство
днешна локална отметка **СЕ ГУБИ**. Доказано от тест **(в)** в `test/new_day_reset_test.dart`
(в момента документира загубата). Поправка за 1.4.14:
- При download — **merge per-habit** вместо blind overwrite: за всеки навик вземи
  **max(local.completedTimes, remote.completedTimes)** когато са в СЪЩИЯ период
  (`periodKeyFor` съвпада); при различен `periodKey` печели по-новият (по-късният период).
- **Обединяване на историята по дни**: `history` map → per-ден `max(dayPercent)` + union на
  ключовете, вместо whole-doc replace.
- Тест **(в)** да стане **РЕГРЕСИЯ** (отметката да се ЗАПАЗВА, не да се губи).
- Място: нов merge слой в `CloudSyncService.sync` преди/вместо `BackupService.apply`.
Това е по-голям проблем на целия sync (last-write-wins на ниво документ), отделен от
нов-ден reset-а — затова е отложен за 1.4.14 след iOS/Android релийза на 1.4.13.

## 1.4.13 (build 33 → 34) — нов-ден reset + widget rollover + cloud-sync reset
Клон `fix/new-day-reset`. Бъг: iOS няма автономна полунощ → дневният reset и widget-ът
зависеха само от студен старт/resume; „Сън 8 часа" излизаше пълен сутрин, widget-ът показваше
вчерашни данни.
- **build 33:** midnight Timer (пренасрочван на resume) + resume reload + WidgetKit timeline с
  нулиран entry за следващата полунощ (`.after`, period-aware) + Android midnight widget push
  (`WidgetService.pushNewDayZero`). Нов `nextLocalMidnight` + `completedTimesAt` helpers.
- **build 34:** `_onCloudSynced` вика `maybeResetForNewDay` ПРЕДИ reload + `uploadNow()` при
  reset — защото облачният download (`BackupService.apply`) връщаше вчерашното `completedTimes`
  без period-aware reset (startup reset се презаписваше).
- 35 теста (нов-ден (а)/(б), инжектиран clock сценарий (а), period-aware нулиране, cloud
  download (a)/(b)/(c)). `maybeResetForNewDay` прие инжектируем `nowOverride` (тестов шев).
