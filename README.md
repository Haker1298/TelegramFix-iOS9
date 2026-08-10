# Telegram Fix for iOS 9

Позволяет старой версии Telegram (5.x) работать на iOS 9.3.6.

## Что делает

| Функция | Описание |
|---------|----------|
| SSL Bypass | Полный обход проверки TLS сертификатов (SecTrustEvaluate + SecTrustSetPolicies + SecTrustEvaluateWithAnchors + NSURLConnection) |
| Version Spoofing | Подмена версии приложения на TG 10.14.5 (build 3812), чтобы сервер не блокировал |
| System Spoofing | Подмена iOS на 15.8.3 / iPhone 12,8 |
| Update Blocker | Блокировка всех диалогов «обновите приложение» (UIAlertView + UIAlertController) |
| App Store Block | Блокировка переходов в App Store из Telegram |

## Установка

1. Скачай `.deb` из [Releases](https://github.com/haker1928/TelegramFix-iOS9/releases) или из Actions artifacts
2. Установи через Filza / iFile / dpkg
3. Открой Telegram

## Логирование

Логи пишутся в:
```
/var/mobile/Library/Logs/TelegramFix.log
```

## Сборка

Требуется macOS + Theos:
```bash
cd TelegramFix-iOS9
make package
```
Или просто запушь в GitHub — соберётся автоматически через Actions.

## Настройка

В начале `Tweak.xm` можно поменять:
- `kSpoofAppVersion` — версия Telegram (по умолчанию 10.14.5)
- `kSpoofBundleVersion` — build номер (по умолчанию 3812)
- `kSpoofSystemVersion` — версия iOS (по умолчанию 15.8.3)
- `kSpoofDeviceModel` — модель устройства (по умолчанию iPhone12,8)

## Совместимость

- iOS 9.0 — 9.3.6
- armv7 + arm64
- Telegram 5.x (тестирулось на 5.14.0)

## Автор

Haker1928