@echo off
echo Building Flutter Web App...
flutter build web --release
cd build\web
python -m http.server 3000

pause
