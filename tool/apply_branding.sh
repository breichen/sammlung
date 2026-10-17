#!/bin/sh
# Im Projektordner ausführen (nach `flutter create .` und `flutter pub get`).
# Setzt den App-Namen "Sammlung" und erzeugt die Icons aus assets/icon/.
set -e
if [ -f android/app/src/main/AndroidManifest.xml ]; then
  perl -pi -e 's/android:label="[^"]*"/android:label="Sammlung"/' android/app/src/main/AndroidManifest.xml
fi
if [ -f ios/Runner/Info.plist ]; then
  perl -0pi -e 's/(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*/${1}Sammlung/; s/(<key>CFBundleName<\/key>\s*<string>)[^<]*/${1}Sammlung/' ios/Runner/Info.plist
fi
dart run flutter_launcher_icons
