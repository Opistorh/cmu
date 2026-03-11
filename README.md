# WallPainter

Минимальное iOS-приложение на SwiftUI + ARKit, которое ищет вертикальные плоскости и закрашивает найденные стены полупрозрачным цветом.

## Что делает

- запускает `ARWorldTrackingConfiguration`
- включает поиск вертикальных плоскостей через `planeDetection = [.vertical]`
- на устройствах с LiDAR включает `sceneReconstruction = .meshWithClassification`
- рисует поверх каждой найденной стены цветную `SCNPlane`

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
