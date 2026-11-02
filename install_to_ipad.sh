#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCODE_APP="${XCODE_APP:-/Volumes/ORICO/Applications/Xcode.app}"
if [[ ! -d "$XCODE_APP" ]]; then
  XCODE_APP="/Applications/Xcode.app"
fi
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")

echo "========================================================"
echo "🐱 喵喵捕猎 (CatToy) - iPad 宠物猫咪互动游戏安装与构建工具"
echo "========================================================"

if [[ "${1:-}" == "--test" ]]; then
  echo "🧪 正在编译并运行自动化单元测试套件 (CatToyTests)..."
  mkdir -p "$PROJECT_DIR/build/Tests"
  "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" \
    -sdk "$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" \
    "$PROJECT_DIR/CatToy/CatBehaviorEngine.swift" \
    "$PROJECT_DIR/CatToy/CatAudioSynth.swift" \
    "$PROJECT_DIR/Tests/CatToyTests.swift" \
    -o "$PROJECT_DIR/build/Tests/CatToyTests"
  "$PROJECT_DIR/build/Tests/CatToyTests"
  exit 0
fi

if [[ "${1:-}" == "--web" ]]; then
  echo "🌐 已启动免签名全屏 Web/PWA 服务："
  echo "👉 请在 iPad 的 Safari 浏览器访问: http://${LAN_IP}:8765"
  echo "💡 提示: 在 Safari 点击「分享 -> 添加到主屏幕」，即可 100% 全屏无地址栏给猫咪玩！"
  cd "$PROJECT_DIR/web"
  exec python3 -m http.server 8765
fi

# 1. 动态生成最新的 CatToy.mobileconfig（包含 playcattoy.com 全屏版 + 100% 纯离线内嵌版）
echo "📦 正在构建全屏 WebClip 描述文件 (CatToy.mobileconfig)..."
WEB_URL="${WEB_URL:-https://playcattoy.com/}"
PROJECT_DIR_ENV="$PROJECT_DIR" WEB_URL_ENV="$WEB_URL" python3 - << 'EOF'
import os, plistlib, base64

project_dir = os.environ["PROJECT_DIR_ENV"]
web_url = os.environ["WEB_URL_ENV"]

with open(os.path.join(project_dir, "web/icon.png"), "rb") as f:
    icon_png = f.read()

with open(os.path.join(project_dir, "web/index.html"), "rb") as f:
    html_bytes = f.read()

data_url = "data:text/html;charset=utf-8;base64," + base64.b64encode(html_bytes).decode("ascii")

profile = {
    "PayloadContent": [
        {
            "FullScreen": True,
            "Icon": icon_png,
            "IgnoreManifestScope": True,
            "IsRemovable": True,
            "Label": "喵喵捕猎",
            "PayloadDescription": "喵喵捕猎 (Peppy Cat 风格 iPad 宠物互动全屏游戏 - playcattoy.com)",
            "PayloadDisplayName": "喵喵捕猎 (全屏版)",
            "PayloadIdentifier": "com.cattoy.peppycat.webclip.fullscreen",
            "PayloadType": "com.apple.webClip.managed",
            "PayloadUUID": "A1B2C3D4-E5F6-4789-9012-3456789ABC01",
            "PayloadVersion": 1,
            "Precomposed": True,
            "URL": web_url,
        },
        {
            "FullScreen": True,
            "Icon": icon_png,
            "IgnoreManifestScope": True,
            "IsRemovable": True,
            "Label": "喵喵离线版",
            "PayloadDescription": "喵喵捕猎 (内嵌全量代码离线版，断网可用、永不过期)",
            "PayloadDisplayName": "喵喵捕猎 (离线版)",
            "PayloadIdentifier": "com.cattoy.peppycat.webclip.offline",
            "PayloadType": "com.apple.webClip.managed",
            "PayloadUUID": "A1B2C3D4-E5F6-4789-9012-3456789ABC02",
            "PayloadVersion": 1,
            "Precomposed": True,
            "URL": data_url,
        }
    ],
    "PayloadDescription": "在 iPad 桌面安装「喵喵捕猎 (playcattoy.com)」全屏猫咪捕猎游戏图标（含 100% 离线版）",
    "PayloadDisplayName": "喵喵捕猎 (CatToy iPad 专享版)",
    "PayloadIdentifier": "com.cattoy.peppycat.profile",
    "PayloadOrganization": "CatToy Studio (playcattoy.com)",
    "PayloadRemovalDisallowed": False,
    "PayloadType": "Configuration",
    "PayloadUUID": "F1E2D3C4-B5A6-4987-8012-3456789ABCDE",
    "PayloadVersion": 1,
}

out_path = os.path.join(project_dir, "web/CatToy.mobileconfig")
with open(out_path, "wb") as f:
    f.write(plistlib.dumps(profile))
EOF

# 2. 通过 USB (MobileDevice.framework -> com.apple.mobile.MCInstall) 直接推送至已连接的 iPad
echo "📲 正在检测 USB 连接的 iPad 并推送全屏桌面应用..."
PROJECT_DIR_ENV="$PROJECT_DIR" python3 - << 'EOF'
import os, ctypes, plistlib

project_dir = os.environ["PROJECT_DIR_ENV"]
with open(os.path.join(project_dir, "web/CatToy.mobileconfig"), "rb") as f:
    profile_bytes = f.read()

md = ctypes.CDLL("/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice")
cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")

cf.CFArrayGetCount.argtypes = [ctypes.c_void_p]
cf.CFArrayGetCount.restype = ctypes.c_long
cf.CFArrayGetValueAtIndex.argtypes = [ctypes.c_void_p, ctypes.c_long]
cf.CFArrayGetValueAtIndex.restype = ctypes.c_void_p
cf.CFStringGetCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32]
cf.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
cf.CFStringCreateWithCString.restype = ctypes.c_void_p
cf.CFDataCreate.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long]
cf.CFDataCreate.restype = ctypes.c_void_p
cf.CFPropertyListCreateWithData.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ulong, ctypes.c_void_p, ctypes.c_void_p]
cf.CFPropertyListCreateWithData.restype = ctypes.c_void_p
cf.CFPropertyListCreateData.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long, ctypes.c_ulong, ctypes.c_void_p]
cf.CFPropertyListCreateData.restype = ctypes.c_void_p
cf.CFDataGetBytePtr.argtypes = [ctypes.c_void_p]
cf.CFDataGetBytePtr.restype = ctypes.c_void_p
cf.CFDataGetLength.argtypes = [ctypes.c_void_p]
cf.CFDataGetLength.restype = ctypes.c_long

def cfstr_to_py(s):
    if not s: return None
    buf = ctypes.create_string_buffer(1024)
    if cf.CFStringGetCString(s, buf, 1024, 0x08000100):
        return buf.value.decode('utf-8', 'ignore')
    return None

def py_to_cfstr(s):
    return cf.CFStringCreateWithCString(None, s.encode('utf-8'), 0x08000100)

md.AMDCreateDeviceList.restype = ctypes.c_void_p
md.AMDeviceConnect.argtypes = [ctypes.c_void_p]
md.AMDeviceConnect.restype = ctypes.c_uint32
md.AMDeviceValidatePairing.argtypes = [ctypes.c_void_p]
md.AMDeviceValidatePairing.restype = ctypes.c_uint32
md.AMDeviceStartSession.argtypes = [ctypes.c_void_p]
md.AMDeviceStartSession.restype = ctypes.c_uint32
md.AMDeviceCopyValue.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
md.AMDeviceCopyValue.restype = ctypes.c_void_p
md.AMDeviceSecureStartService.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
md.AMDeviceSecureStartService.restype = ctypes.c_uint32
md.AMDServiceConnectionSendMessage.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long]
md.AMDServiceConnectionSendMessage.restype = ctypes.c_int
md.AMDServiceConnectionReceiveMessage.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p]
md.AMDServiceConnectionReceiveMessage.restype = ctypes.c_int

dev_list = md.AMDCreateDeviceList()
if not dev_list or cf.CFArrayGetCount(dev_list) == 0:
    print("❌ 未检测到 USB 连接的 iPad，请检查数据线连接并在 iPad 上点击「信任此电脑」。")
    raise SystemExit(1)

dev = cf.CFArrayGetValueAtIndex(dev_list, 0)
md.AMDeviceConnect(dev)
md.AMDeviceValidatePairing(dev)
md.AMDeviceStartSession(dev)

dev_name = cfstr_to_py(md.AMDeviceCopyValue(dev, None, py_to_cfstr("DeviceName"))) or "iPad"
os_ver = cfstr_to_py(md.AMDeviceCopyValue(dev, None, py_to_cfstr("ProductVersion"))) or "Unknown"
print(f"🔍 已连接设备: {dev_name} (iPadOS {os_ver})")

conn = ctypes.c_void_p()
rc = md.AMDeviceSecureStartService(dev, py_to_cfstr("com.apple.mobile.MCInstall"), None, ctypes.byref(conn))
req_bytes = plistlib.dumps({"RequestType": "InstallProfile", "Payload": profile_bytes})
cf_data = cf.CFDataCreate(None, req_bytes, len(req_bytes))
cf_plist = cf.CFPropertyListCreateWithData(None, cf_data, 0, None, None)

md.AMDServiceConnectionSendMessage(conn, cf_plist, 200)
resp = ctypes.c_void_p()
md.AMDServiceConnectionReceiveMessage(conn, ctypes.byref(resp), None)
if resp.value:
    out_data = cf.CFPropertyListCreateData(None, resp, 100, 0, None)
    length = cf.CFDataGetLength(out_data)
    ptr = cf.CFDataGetBytePtr(out_data)
    raw = ctypes.string_at(ptr, length)
    print("✅ USB 推送结果:", plistlib.loads(raw))
EOF

echo ""
echo "🎉 已成功将「喵喵捕猎」推送到您的 iPad！"
echo "👉 请在 iPad 上打开：「设置 (Settings)」-> 左侧顶部点击「已下载描述文件 (Profile Downloaded)」-> 点击右上角「安装 (Install)」"
echo "👉 安装后 iPad 桌面上即会出现带猫咪脚印图标的【喵喵捕猎】与【喵喵离线版】全屏应用！"
echo "👉 如需启动局域网 Web 服务，请运行: ./install_to_ipad.sh --web"
