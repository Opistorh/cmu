# WallPainter

Минимальное iOS-приложение на SwiftUI, в котором сейчас есть два режима:

- AR-сканер стен на `ARKit`
- извлечение развёрток стен из PDF-дизайн-проекта

## Что делает

- запускает `ARWorldTrackingConfiguration`
- включает поиск вертикальных плоскостей через `planeDetection = [.vertical]`
- на устройствах с LiDAR включает `sceneReconstruction = .meshWithClassification`
- рисует поверх каждой найденной стены цветную `SCNPlane`
- во втором разделе открывает PDF через системный picker
- анализирует страницы через `PDFKit` и OCR (`Vision`)
- ищет общий план проекта и страницы с развёртками стен
- пытается определить помещение по заголовкам листов
- собирает “карту проекта”: план в центре, рядом карточки помещений с их развёртками
- дополнительно формирует отдельный PDF с найденными развёртками

## Как запустить

1. Откройте `WallPainter.xcodeproj` в Xcode.
2. Укажите свой `Bundle Identifier` вместо `com.example.WallPainter`.
3. Выберите физический iPhone Pro с LiDAR.
4. Разрешите доступ к камере и наведите устройство на стены.

## Проверка сборки

Если `xcodebuild` сейчас не работает и пишет про `CommandLineTools`, переключите active developer directory на установленный Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -project WallPainter.xcodeproj -scheme WallPainter -destination 'generic/platform=iOS' build
```
