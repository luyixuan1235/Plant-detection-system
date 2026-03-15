# 项目启动指南

## 当前状态检查

✅ 项目结构完整
✅ 模型文件已就位 (app/cnn/plant_disease_cnn.pth)
✅ 环境变量已配置 (.env)
✅ API Key 已设置

## 启动步骤

### 1. 安装依赖包

```bash
pip install -r requirements.txt
```

**注意**: 如果你已经安装了 torch，可能需要根据你的系统选择合适的版本。

### 2. 验证配置

确认 `.env` 文件中的配置正确：
- ✓ DEEPSEEK_API_KEY 已设置
- ✓ SECRET_KEY 已设置
- ✓ MODEL_PATH 指向正确位置

### 3. 启动服务器

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

或者使用简化命令：
```bash
uvicorn app.main:app --reload
```

### 4. 访问 API 文档

启动成功后，打开浏览器访问：
- API 文档: http://localhost:8000/docs
- 备用文档: http://localhost:8000/redoc
- 健康检查: http://localhost:8000/health

## 测试流程

### 1. 注册用户

```bash
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "is_admin": false
  }'
```

### 2. 登录获取 Token

```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=password123"
```

### 3. 上传图片检测疾病

使用 Swagger UI (http://localhost:8000/docs) 更方便测试文件上传。

## 可能遇到的问题

### 问题 1: ModuleNotFoundError
**解决**: 确保已安装所有依赖 `pip install -r requirements.txt`

### 问题 2: 模型加载失败
**检查**:
- 模型文件是否存在: `ls -la app/cnn/plant_disease_cnn.pth`
- .env 中的 MODEL_PATH 是否正确

### 问题 3: DeepSeek API 调用失败
**检查**:
- API Key 是否正确
- 网络连接是否正常
- API 配额是否充足

## 项目结构

```
d:\SoftwareM/
├── app/
│   ├── cnn/                    # CNN 模型相关
│   │   ├── plant_disease_cnn.pth
│   │   ├── predict.py
│   │   └── train.py
│   ├── core/                   # 核心配置
│   │   ├── config.py          # 配置管理
│   │   ├── database.py        # 数据库
│   │   └── security.py        # 认证
│   ├── models/                 # 数据库模型
│   ├── schemas/                # API 模型
│   ├── routers/                # 路由
│   │   ├── auth.py
│   │   ├── trees.py
│   │   └── patrols.py
│   ├── services/               # 业务逻辑
│   │   ├── disease_detection.py
│   │   └── deepseek_client.py
│   ├── static/uploads/         # 上传文件
│   └── main.py                 # 主应用
├── .env                        # 环境变量 (已配置)
├── requirements.txt            # 依赖包
└── README.md                   # 项目文档
```

## API 端点列表

### 认证相关
- `POST /api/auth/register` - 注册用户
- `POST /api/auth/login` - 登录
- `GET /api/auth/me` - 获取当前用户信息

### 树木管理
- `POST /api/trees/detect` - 上传图片检测疾病
- `GET /api/trees/` - 获取所有树木
- `GET /api/trees/{tree_id}` - 获取单个树木详情
- `PUT /api/trees/{tree_id}/status` - 更新树木状态

### 巡逻管理 (仅管理员)
- `POST /api/patrols/checkin` - 打卡
- `GET /api/patrols/` - 获取我的巡逻记录
- `GET /api/patrols/all` - 获取所有巡逻记录

## 下一步

1. 安装依赖包
2. 启动服务器
3. 访问 http://localhost:8000/docs 测试 API
4. 开始开发前端应用
