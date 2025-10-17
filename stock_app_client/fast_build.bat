@echo off
echo ===== Flutter快速构建脚本 =====

echo [1/5] 停止Gradle守护进程...
call gradlew --stop

echo [2/5] 清理缓存...
flutter clean

echo [3/5] 获取依赖...
flutter pub get

echo [4/5] 预编译...
flutter build apk --debug --no-pub --build-shared-library

echo [5/5] 完成！
echo ===== 构建完成 =====
pause 