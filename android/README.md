# Android build

1. Godot: Editor > Manage Export Templates > Download (4.7).
2. Editor Settings > Export > Android: set Java SDK (JDK 17) and Android SDK paths.
3. Project > Install Android Build Template (creates `android/build/`, git-ignored).
4. Signing: see `signing.properties.example`. Debug builds use Godot's debug keystore.
5. Project > Export > Android > Export Project (`exports/ninja.apk`), or one-click deploy to a USB phone.

Desktop touch test: `godot --path . -- --touch`
