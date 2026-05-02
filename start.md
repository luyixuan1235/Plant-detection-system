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

---

## 2. 环境准备（首次一次）

### 2.1 Python 依赖

```powershell
cd "C:\Users\23353\Desktop\Plant Monitoring\Plant Monitoring\Plant"
python -m pip install -r requirements.txt
```

### 2.2 Flutter 依赖

```powershell
cd "C:\Users\23353\Desktop\Plant Monitoring\Plant Monitoring\Plant\FRONTEND"
flutter pub get
```

### 2.3 cloudflared（仅 iPhone 外网访问需要）

```powershell
winget install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements
```

如果提示“已安装且无可升级版本”，是正常现象。

检查命令：

```powershell
cloudflared --version
```

---

## 3. 本地电脑开发（推荐）

### 3.1 配置后端地址（前端）

文件：

`Plant Monitoring\Plant Monitoring\Plant\FRONTEND\lib\config\api_config.dart`

本地开发时：

```dart
static const String baseUrl = 'http://127.0.0.1:8000';
```

### 3.2 启动后端

```powershell
cd "C:\Users\23353\Desktop\Plant Monitoring\Plant Monitoring\Plant\BACKEND"
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

健康检查：

```text
http://127.0.0.1:8000/health
```

应返回：

```json
{"ok":true,"version":"0.1.0"}
```

### 3.3 启动前端（Chrome）

```powershell
cd "C:\Users\23353\Desktop\Plant Monitoring\Plant Monitoring\Plant\FRONTEND"
flutter run -d chrome
```

---

## 4. 管理员账号与管理员页

### 4.1 创建管理员账号

```powershell
cd "C:\Users\23353\Desktop\Plant Monitoring\Plant Monitoring\Plant\BACKEND"
python -m backend.manage_users create --username admin --password 123456 --role admin
```

若账号已存在，可重置：

```powershell
python -m backend.manage_users role --username admin --role admin
python -m backend.manage_users passwd --username admin --password 123456
```

### 4.2 管理员页功能（当前实现）

- 管理员登录后进入浇水打卡页面
- 点击按钮完成“今日浇水打卡”
- 打卡位置使用 `assets/data/campus_plants.json` 的 `default_location`
- 显示最新打卡时间（UTC+8）和最近 5 条记录
- 右上角三点菜单可跳转学生共用树木分布页

---

## 5. iPhone 访问（Cloudflare Tunnel）

> 手机访问时，前后端都建议走 HTTPS tunnel。

### 5.1 启动后端（终端 1）

```powershell
cd "C:\Users\23353\Desktop\Plant Monitoring(5)\Plant Monitoring\Plant\BACKEND"
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

### 5.2 后端 tunnel（终端 2）

```powershell
cloudflared tunnel --url http://localhost:8000
```

记下输出的后端地址，例如：

`https://xxxx.trycloudflare.com`


### 5.3 启动前端 web-server（终端 3）

把下面命令里的 https://xxxx.trycloudflare.com 换成你第 2 步得到的 后端 tunnel 地址：

```powershell
cd "C:\Users\23353\Desktop\Plant Monitoring(5)\Plant Monitoring\Plant\FRONTEND"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8085 --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
```

### 5.4 前端 tunnel（终端 4）

```powershell
cloudflared tunnel --url http://localhost:8085
```

会得到前端地址：

`https://yyyy.trycloudflare.com`

iPhone Safari 打开这个 前端 tunnel 地址，然后登录。不要打开后端 tunnel 地址。
---

## 6. 常见问题

### 6.1 手机提示 `Cannot connect to server` 且 BaseURL 是 `127.0.0.1`

原因：你在手机端仍使用了本地回环地址。  
解决：把 `api_config.dart` 改成后端 tunnel 的 `https://...trycloudflare.com`，并重启前端 web-server。

### 6.2 `cloudflared` 命令不存在

如果已安装但命令不可用，使用完整路径：

```powershell
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" --version
```

或把该目录加入用户 PATH 后重开终端。

### 6.3 前端改了 `api_config.dart` 但手机还是旧地址

`baseUrl` 是编译期常量，必须重启 Flutter web-server，不是仅热重载。

### 6.4 端口被占用

- 关闭旧 Flutter 进程（终端里按 `q` 或结束进程）
- 再重新运行固定端口命令（`--web-port 8085`）

### 6.5 浇水打卡记录不更新

- 确认后端已更新到包含 `/admin/watering/*` 的版本
- 确认管理员账号登录成功（`role=admin`）
- 在后端终端观察请求日志是否到达

---

## 7. 当前推荐启动顺序（最稳）

1. 起后端（8000）
2. 开后端 tunnel（8000 -> https）
3. 改前端 `baseUrl` 为后端 tunnel 地址
4. 起前端 web-server（8085）
5. 开前端 tunnel（8085 -> https）
6. iPhone 打开前端 tunnel 地址并登录

