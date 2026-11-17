#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TEAM_ID="${TEAM_ID:?need TEAM_ID}"
BUNDLE="${BUNDLE_ID:-com.maishu.app.8AR5Y2B4JS}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SCHEME="${SCHEME:-App}"
WORKSPACE="ios/App/App.xcworkspace"
ARCHIVE="build/App.xcarchive"
EXPORT_DIR="build/export"

echo "==> 环境"; xcodebuild -version; node -v

if [ "${SKIP_PODS:-0}" != "1" ]; then
  echo "==> pod install"
  (cd ios/App && sed -i '' "s/platform :ios, '[0-9.]*'/platform :ios, '16.0'/" Podfile && pod install --repo-update)
fi

echo "==> 归档"
rm -rf build "$ARCHIVE" "$EXPORT_DIR"
mkdir -p build
xcodebuild \
  -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release \
  -sdk iphoneos -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  IPHONEOS_DEPLOYMENT_TARGET=16.0 \
  MARKETING_VERSION="1.0" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  ${ASC_KEY_PATH:+-authenticationKeyPath "$ASC_KEY_PATH"} \
  ${ASC_KEY_ID:+-authenticationKeyID "$ASC_KEY_ID"} \
  ${ASC_ISSUER_ID:+-authenticationKeyIssuerID "$ASC_ISSUER_ID"} \
  | tail -30

echo "==> 导出并上传 TestFlight"
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><false/>
  <key>destination</key><string>upload</string>
</dict></plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  ${ASC_KEY_PATH:+-authenticationKeyPath "$ASC_KEY_PATH"} \
  ${ASC_KEY_ID:+-authenticationKeyID "$ASC_KEY_ID"} \
  ${ASC_ISSUER_ID:+-authenticationKeyIssuerID "$ASC_ISSUER_ID"} \
  | tee build/export.log | tail -40

echo "==> 完成"
grep -q "Upload succeeded" build/export.log && echo "上传成功" || echo "未确认上传，检查日志"
