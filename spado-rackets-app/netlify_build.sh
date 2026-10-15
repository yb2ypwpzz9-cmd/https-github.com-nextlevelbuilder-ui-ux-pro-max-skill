#!/usr/bin/env bash
# Compila la app web en Netlify. Netlify no trae Flutter, así que lo descarga
# (versión fija, la misma con la que se ha probado la app) y lanza la
# compilación. Se ejecuta sola en cada despliegue; no hace falta tocar nada.
set -euo pipefail

FLUTTER_VERSION="3.47.7"
FLUTTER_DIR="$HOME/flutter-$FLUTTER_VERSION"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics --enable-web
flutter precache --web
flutter pub get
flutter build web --release
