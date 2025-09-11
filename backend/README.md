# 应用目录

这个目录包含了所有的Go应用程序，每个应用都可以独立构建为Docker镜像并部署到SCF云函数。

## 📁 目录结构

```
backend/
├── website-api/           # 主网站API服务
├── user-service/          # 用户管理服务
├── notification-service/  # 通知服务
└── README.md
```

## 🚀 应用说明

### website-api
主要的网站API服务，提供：
- 用户认证
- 基础API接口
- 健康检查
- 统计信息

**端口**: 9000 (本地开发时为9000)
**路径**: `/api/v1/*`

### user-service
用户管理服务，提供：
- 用户CRUD操作
- 用户状态管理
- 用户列表查询

**端口**: 9001 (本地开发时)
**路径**: `/api/v1/users/*`

### notification-service
通知服务，提供：
- 邮件通知
- 短信通知
- 推送通知
- 通知状态跟踪

**端口**: 9002 (本地开发时)
**路径**: `/api/v1/notifications/*`

## 🛠️ 本地开发

### 运行单个服务

```bash
# 运行website-api
cd backend/website-api
go run main.go

# 运行user-service
cd backend/user-service
PORT=9001 go run main.go

# 运行notification-service
cd backend/notification-service
PORT=9002 go run main.go
```

### 使用Docker运行

```bash
# 构建镜像
cd backend/website-api
docker build -t website-api .

# 运行容器
docker run -p 9000:9000 website-api
```

### 使用Makefile

```bash
# 从项目根目录
make run-local          # 运行website-api
make docker-build       # 构建所有Docker镜像
make docker-run         # 运行Docker容器
```

## 📝 添加新应用

1. **创建应用目录**
   ```bash
   mkdir backend/new-service
   cd backend/new-service
   ```

2. **初始化Go模块**
   ```bash
   go mod init new-service
   ```

3. **创建main.go文件**
   参考现有应用的结构

4. **创建Dockerfile**
   ```dockerfile
   FROM golang:1.21-alpine AS builder
   WORKDIR /app
   COPY go.mod go.sum ./
   RUN go mod download
   COPY . .
   RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .
   
   FROM alpine:latest
   RUN apk --no-cache add ca-certificates
   WORKDIR /root/
   COPY --from=builder /app/main .
   EXPOSE 9000
   CMD ["./main"]
   ```

5. **更新Terraform配置**
   在 `infrastructure/variables.tf` 中的 `app_names` 变量添加新应用名称：
   ```hcl
   variable "app_names" {
     default = ["website-api", "user-service", "notification-service", "new-service"]
   }
   ```

6. **重新部署**
   ```bash
   make apply
   ```

## 🔧 开发规范

### 代码结构
- 使用Gin框架构建HTTP服务
- 支持SCF和本地运行两种模式
- 统一的错误处理和响应格式
- CORS支持

### 环境变量
- `SCF_RUNTIME_API`: SCF运行时API（自动设置）
- `PORT`: 本地运行端口
- `TENCENTCLOUD_REGION`: 腾讯云地域
- `SCF_FUNCTIONNAME`: SCF函数名称

### API规范
- 使用RESTful API设计
- 统一的JSON响应格式
- 适当的HTTP状态码
- API版本控制 (`/api/v1/`)

### 健康检查
每个服务都应该提供健康检查端点：
```
GET /api/v1/{service}/health
```

## 🧪 测试

### 单元测试
```bash
cd backend/website-api
go test -v ./...
```

### API测试
```bash
# 健康检查
curl http://localhost:9000/api/v1/health

# 用户服务
curl http://localhost:9001/api/v1/users/health

# 通知服务
curl http://localhost:9002/api/v1/notifications/health
```

## 📦 部署

应用会自动构建为Docker镜像并推送到腾讯云TCR，然后部署到SCF云函数。

部署流程：
1. Terraform创建TCR仓库
2. 本地构建Docker镜像
3. 推送镜像到TCR
4. 创建SCF函数使用镜像
5. 配置API网关触发器

## 🔍 监控和日志

- **CLS日志**: 所有应用日志自动收集到腾讯云CLS
- **API网关监控**: 请求量、延迟、错误率等指标
- **健康检查**: 定时检查服务可用性

## 🤝 贡献

1. 遵循现有的代码风格
2. 添加适当的注释和文档
3. 确保所有测试通过
4. 更新相关文档