# Plant Monitoring 启动说明（最新版）

本说明基于当前项目实际代码整理，适用于：

- `Plant/BACKEND`：FastAPI 后端（当前主后端）
- `Plant/FRONTEND`：Flutter Web 前端（当前主前端）
- `SoftwareM`：模型与早期服务目录（当前前端**不直接**连接此目录）

---

## 1. 项目结构与当前主链路

```text
Plant Monitoring/
└─ Plant Monitoring/
   ├─ Plant/
   │  ├─ BACKEND/   # 当前后端
   │  └─ FRONTEND/  # 当前前端
   └─ SoftwareM/    # 模型与早期代码（不作为当前前端运行后端）
```

当前前端默认调用 `Plant/BACKEND` 的接口。

## 2. 路径说明

本项目可在 Windows 和 macOS 下运行。由于不同电脑的项目保存位置不同，下面命令中的路径需要根据自己的实际位置调整。

### 2.1 Windows 示例路径

如果项目放在 Windows 桌面，可以类似：

`C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant`

其中后端目录为：

`C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\BACKEND`

前端目录为：

`C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\FRONTEND`

### 2.2 macOS 示例路径

如果项目放在 macOS 桌面，可以类似：

`/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant`

其中后端目录为：

`/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/BACKEND`

前端目录为：

`/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/FRONTEND`

### 2.3 后续命令说明

后续启动命令会分别给出 Windows 和 macOS 写法。

如果你的项目路径不同，请把命令中的路径替换成自己电脑上的实际路径。

Windows 路径通常使用反斜杠：

`C:\Users\用户名\Desktop\...`

macOS 路径通常使用正斜杠：

`/Users/用户名/Desktop/...`

如果路径中包含空格或中文，建议在命令中使用英文双引号包住路径，例如：

Windows：

`cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\BACKEND"`

macOS：

`cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/BACKEND"`

后续命令中：

- Windows 通常使用 `python`
- macOS 通常使用 `python3`
- Windows 安装 `cloudflared` 推荐使用 `winget`
- macOS 安装 `cloudflared` 推荐使用 `brew`





## 3. 环境准备（首次一次）

### 3.1 Python 依赖

Windows：

```powershell
cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant"
python -m pip install -r requirements.txt
```

macOS：

```bash
cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant"
python3 -m pip install -r requirements.txt
```

### 3.2 Flutter 依赖

Windows：

```powershell
cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\FRONTEND"
flutter pub get
```

macOS：

```bash
cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/FRONTEND"
flutter pub get
```

### 3.3 cloudflared（仅 iPhone 外网访问需要）

Windows：

```powershell
winget install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements
cloudflared --version
```

如果命令不可用，可以使用完整路径：

```powershell
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" --version
```

macOS：

```bash
brew install cloudflared
cloudflared --version
```

如果显示已安装或输出版本号，均为正常现象。

手机端依赖 HTTPS 才能使用 Safari 摄像头权限（二维码扫描、拍照上传），所以 iPhone 访问必须保证 tunnel 正常。

如果电脑安装了 Cloudflare WARP、Clash、V2Ray、VPN、校园网代理等，请在启动 tunnel 前先关闭。

如果 cloudflared 日志出现 `ip=198.18.x.x` 或 `TLS handshake with edge error: EOF`，说明 cloudflared 的出站 TLS 被 WARP、代理或当前网络环境拦截，先关闭代理或切换手机热点后再启动。

## 4. 本地电脑开发（推荐）

### 4.1 配置后端地址（前端）

文件位置：

Windows：

```text
Plant Monitoring\Plant Monitoring\Plant\FRONTEND\lib\config\api_config.dart
```

macOS：

```text
Plant Monitoring/Plant Monitoring/Plant/FRONTEND/lib/config/api_config.dart
```

本地电脑开发时，默认后端地址为：

```text
http://127.0.0.1:8000
```

通常不需要手动修改 `api_config.dart`。

如果使用手机访问或 Cloudflare Tunnel，推荐在启动前端时通过以下方式传入后端地址，而不是直接改源码：

```bash
--dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
```

### 4.2 启动后端

Windows：

```powershell
cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\BACKEND"
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

macOS：

```bash
cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/BACKEND"
python3 -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

健康检查：

```text
http://127.0.0.1:8000/health
```

应返回：

```json
{"ok":true,"version":"0.1.0"}
```

### 4.3 启动前端（Chrome）

Windows：

```powershell
cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\FRONTEND"
flutter run -d chrome
```

macOS：

```bash
cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/FRONTEND"
flutter run -d chrome
```

## 5. 管理员账号与管理员页

### 5.1 创建管理员账号

Windows：

```powershell
cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\BACKEND"
python -m backend.manage_users create --username admin --password 123456 --role admin
```

macOS：

```bash
cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/BACKEND"
python3 -m backend.manage_users create --username admin --password 123456 --role admin
```

若账号已存在，可重置：

Windows：

```powershell
python -m backend.manage_users role --username admin --role admin
python -m backend.manage_users passwd --username admin --password 123456
```

macOS：

```bash
python3 -m backend.manage_users role --username admin --role admin
python3 -m backend.manage_users passwd --username admin --password 123456
```

### 5.2 管理员页功能（当前实现）

- 管理员登录后进入浇水打卡页面
- 点击按钮完成“今日浇水打卡”
- 打卡位置使用 `assets/data/campus_plants.json` 的 `default_location`
- 显示最新打卡时间（UTC+8）和最近 5 条记录
- 右上角三点菜单可跳转学生共用树木分布页

## 6. iPhone 访问（Cloudflare Tunnel）

手机访问时，前后端都建议走 HTTPS tunnel。

iPhone Safari 的摄像头权限只在 HTTPS 或 localhost 下可用。本项目的二维码扫描、拍照上传都依赖摄像头，因此不能用普通 `http://电脑IP` 代替 Cloudflare HTTPS tunnel。

### 6.0 启动前检查（必须）

- 关闭 Cloudflare WARP / 1.1.1.1 WARP
- 关闭 Clash、V2Ray、NekoRay、VPN、校园网代理等会接管系统网络的工具
- 如果学校网络拦截 Cloudflare，电脑先连接手机热点再启动 tunnel
- tunnel 正常时日志里应看到类似 `Registered tunnel connection ... protocol=http2`，并且 IP 应类似 `198.41.x.x`，不应是 `198.18.x.x`

### 6.1 启动后端（终端 1）

Windows：

```powershell
cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\BACKEND"
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

macOS：

```bash
cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/BACKEND"
python3 -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

电脑浏览器先打开：

```text
http://127.0.0.1:8000/health
```

应返回：

```json
{"ok":true,"version":"0.1.0"}
```

### 6.2 后端 tunnel（终端 2）

Windows / macOS 都可以使用：

```bash
cloudflared tunnel --protocol http2 --edge-ip-version 4 --url http://localhost:8000
```

记下输出的后端地址，例如：

```text
https://xxxx.trycloudflare.com
```

### 6.3 启动前端 web-server（终端 3）

把下面命令里的 `https://xxxx.trycloudflare.com` 换成你第 6.2 步得到的后端 tunnel 地址。

Windows：

```powershell
cd "C:\Users\luyixuan\Desktop\大三下\软件项目管理\Plant Monitoring\Plant Monitoring\Plant\FRONTEND"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8085 --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
```

macOS：

```bash
cd "/Users/samuel/Desktop/Plant Monitoring/Plant Monitoring/Plant/FRONTEND"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8085 --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
```

这里必须传入：

```text
--dart-define=API_BASE_URL=后端tunnel地址
```

手机浏览器里的 `127.0.0.1` 指向手机自己，不是电脑后端。

### 6.4 前端 tunnel（终端 4）

Windows / macOS 都可以使用：

```bash
cloudflared tunnel --protocol http2 --edge-ip-version 4 --url http://localhost:8085
```

会得到前端地址：

```text
https://yyyy.trycloudflare.com
```

iPhone Safari 打开这个前端 tunnel 地址，然后登录。不要打开后端 tunnel 地址。

## 7. 常见问题

### 7.1 手机提示 Cannot connect to server 且 BaseURL 是 127.0.0.1

原因：手机端仍在使用本地回环地址。

解决：重新启动前端，并传入后端 tunnel 地址：

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8085 --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
```

### 7.2 cloudflared 命令不存在

Windows：

```powershell
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" --version
```

或把该目录加入用户 PATH 后重开终端。

macOS：

```bash
brew install cloudflared
cloudflared --version
```

### 7.3 cloudflared 日志出现 TLS handshake with edge error: EOF

如果日志类似：

```text
Unable to establish connection with Cloudflare edge error="TLS handshake with edge error: EOF"
ip=198.18.x.x
```

原因：cloudflared 的出站连接被 WARP、代理、VPN 或当前网络环境拦截。`198.18.x.x` 不是正常 Cloudflare Edge IP。

解决：

- 退出 Cloudflare WARP / 1.1.1.1 WARP
- 退出 Clash、V2Ray、VPN、校园网代理
- 重开 PowerShell 或终端
- 重新执行 tunnel 命令：

```bash
cloudflared tunnel --protocol http2 --edge-ip-version 4 --url http://localhost:8000
cloudflared tunnel --protocol http2 --edge-ip-version 4 --url http://localhost:8085
```

如果仍然失败，切换电脑网络到手机热点。

### 7.4 cloudflared 日志出现大量 stream canceled

如果同时看到 `no recent network activity`，说明 tunnel 连接正在断开或重连。优先按 7.3 关闭 WARP、代理或 VPN，并继续使用：

```bash
--protocol http2 --edge-ip-version 4
```

### 7.5 前端改了 api_config.dart 但手机还是旧地址

`baseUrl` 属于编译期常量，必须重启 Flutter web-server，不是仅热重载。

### 7.6 端口被占用

- 关闭旧 Flutter 进程（终端里按 `q` 或结束进程）
- 再重新运行固定端口命令（`--web-port 8085`）

### 7.7 浇水打卡记录不更新

- 确认后端已更新到包含 `/admin/watering/*` 的版本
- 确认管理员账号登录成功（`role=admin`）
- 在后端终端观察请求日志是否到达

## 8. 当前推荐启动顺序（最稳）

1. 启动后端（8000）
2. 启动后端 tunnel（`8000 -> https`，使用 `--protocol http2 --edge-ip-version 4`）
3. 启动前端时传入 `--dart-define=API_BASE_URL=后端tunnel地址`
4. 启动前端 web-server（8085）
5. 启动前端 tunnel（`8085 -> https`，使用 `--protocol http2 --edge-ip-version 4`）
6. iPhone 打开前端 tunnel 地址并登录

