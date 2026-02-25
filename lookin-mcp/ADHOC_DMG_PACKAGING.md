# Lookin ad-hoc DMG 打包说明

本文档记录团队内测场景下，将 `Lookin.app` 打成 ad-hoc `dmg` 的可执行流程（不依赖企业分发账号）。

## 1. 适用范围

- 仅用于团队内部测试分发。
- 不适用于正式外部分发（无 Developer ID 公证）。

## 2. 发送方（打包方）步骤

### 2.1 推荐：直接执行脚本

脚本位置：`lookin-mcp/package_adhoc_dmg.sh`

```bash
cd /Users/bytedance/AnyWorkspace/testSwiftUIProject/Lookin
./lookin-mcp/package_adhoc_dmg.sh
```

可选环境变量：

- `WORKSPACE`（默认 `Lookin.xcworkspace`）
- `SCHEME`（默认 `LookinClient`）
- `CONFIGURATION`（默认 `Release`）
- `DERIVED_DATA_PATH`（默认 `/tmp/lookin-deriveddata`）
- `OUTPUT_DIR`（默认 `/tmp/lookin-packages`）
- `VOLUME_NAME`（默认 `Lookin`）

示例：

```bash
cd /Users/bytedance/AnyWorkspace/testSwiftUIProject/Lookin
OUTPUT_DIR=/tmp/my-packages VOLUME_NAME=LookinInternal ./lookin-mcp/package_adhoc_dmg.sh
```

### 2.2 手工命令（与脚本等价）

在项目根目录执行：

```bash
cd /Users/bytedance/AnyWorkspace/testSwiftUIProject/Lookin

# 1) Release 构建（输出到 /tmp）
xcodebuild -workspace Lookin.xcworkspace \
  -scheme LookinClient \
  -configuration Release \
  -derivedDataPath /tmp/lookin-deriveddata \
  build

# 2) ad-hoc 重签名（无证书）
APP="/tmp/lookin-deriveddata/Build/Products/Release/Lookin.app"
codesign --remove-signature "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# 3) 组装 DMG staging 目录
STAGE=$(mktemp -d /tmp/lookin-dmg-stage.XXXXXX)
cp -R "$APP" "$STAGE/Lookin.app"
ln -s /Applications "$STAGE/Applications"

# 4) 生成 DMG
mkdir -p /tmp/lookin-packages
DMG="/tmp/lookin-packages/Lookin-adhoc-$(date +%Y%m%d-%H%M).dmg"
hdiutil create -volname "Lookin" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

# 5) 清理与校验
rm -rf "$STAGE"
shasum -a 256 "$DMG"
ls -lh "$DMG"
echo "DMG_PATH=$DMG"
```

## 3. 本次实际产物（示例）

- `DMG_PATH=/tmp/lookin-packages/Lookin-adhoc-20260225-2153.dmg`
- `SHA-256=85a73394c677bf42a426adcb3c6f215307a3d3f9be80375da7b2eb8669242d46`

## 4. 接收方安装步骤

```bash
# 1) 双击 dmg，拖入 /Applications（或手工复制）

# 2) 去掉隔离标记（关键）
xattr -dr com.apple.quarantine /Applications/Lookin.app

# 3) 启动
open /Applications/Lookin.app
```

如仍被拦截：

1. Finder 右键 `Lookin.app` -> `打开`。
2. 或在 `系统设置 -> 隐私与安全性` 点击“仍要打开”。

## 5. 已知限制

1. ad-hoc 包不是受信任发布者签名，会触发 Gatekeeper 手动放行。
2. 无 notarization，不适合正式对外分发。
3. 企业 MDM 策略可能阻止运行。
4. 适合内测，不适合长期自动更新发布。
