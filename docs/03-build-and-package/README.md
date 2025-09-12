# 🔨 第三步: 编译及镜像制作

本文档介绍如何编译前端应用、后端服务并制作Docker镜像。

## 📋 前置条件

- 完成 [第二步: 基础设施搭建](../02-infrastructure-setup/README.md)
- 确保开发环境已正确配置

## ⚠️ 架构兼容性重要说明

**M4芯片用户必读**: 由于本地开发环境使用ARM64架构，而腾讯云SCF运行环境为x86-64架构，所有Go应用必须进行交叉编译。我们的脚本已自动处理此问题。

**关键技术要点**:
- 交叉编译参数: `CGO_ENABLED=0 GOOS=linux GOARCH=amd64`
- Docker镜像平台: `--platform linux/amd64`
- 自动架构验证: 确保生成的二进制文件为x86-64格式

## 🤖 自动化脚本（推荐）

**强烈推荐使用自动化脚本**，它们已经处理了M4芯片到腾讯云SCF x86-64的架构兼容性问题：

### 1. 前端构建
```bash
# 查看所有选项
./scripts/03-build-and-package/build-frontend.sh --help

# 常用构建命令
./scripts/03-build-and-package/build-frontend.sh                    # 生产构建
./scripts/03-build-and-package/build-frontend.sh --dev             # 开发构建
./scripts/03-build-and-package/build-frontend.sh --clean --prod    # 清理后生产构建
./scripts/03-build-and-package/build-frontend.sh --analyze         # 构建并分析包大小
```

### 2. 后端构建
```bash
# 查看所有选项
./scripts/03-build-and-package/build-backend.sh --help

# 常用构建命令
./scripts/03-build-and-package/build-backend.sh                    # 构建所有服务
./scripts/03-build-and-package/build-backend.sh website-api        # 只构建API服务
./scripts/03-build-and-package/build-backend.sh --clean --verbose  # 清理后详细构建
```

### 3. Docker镜像构建
```bash
# 查看所有选项
./scripts/03-build-and-package/build-docker-images.sh --help

# 常用构建命令
./scripts/03-build-and-package/build-docker-images.sh                          # 构建所有镜像
./scripts/03-build-and-package/build-docker-images.sh website-api frontend     # 构建指定服务
./scripts/03-build-and-package/build-docker-images.sh --tag=v1.0.0 --push      # 构建并推送
```

**脚本特性**:
- ✅ 自动处理架构兼容性（ARM64 → x86-64）
- ✅ 支持单个服务或批量构建
- ✅ 提供详细的构建信息和错误处理
- ✅ 支持多种构建选项和参数
- ✅ 自动创建Dockerfile（如果不存在）
- ✅ 构建结果验证和统计

---

## 📋 手动构建步骤（备选方案）

如果需要手动构建或了解构建细节，可以参考以下步骤：

### 🎨 前端应用构建

#### 1.1 准备前端环境

```bash
cd frontend

# 安装依赖（如果尚未安装）
npm install

# 清理之前的构建
rm -rf dist build
```

#### 1.2 执行构建

```bash
# 生产环境构建
npm run build

# 开发环境构建（如果有相应脚本）
npm run build:dev
```

#### 1.3 验证构建结果

```bash
# 检查构建输出
ls -la dist/  # 或 build/

# 查看构建统计
du -sh dist/
```

### 🔧 后端服务构建

**重要**: 必须使用交叉编译参数确保x86-64兼容性。

#### 2.1 编译website-api服务

```bash
echo "🔨 编译website-api服务..."
cd backend/website-api

# 下载依赖
go mod download

# 交叉编译 - 针对腾讯云SCF x86-64架构
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o bin/website-api .

# 验证架构
file bin/website-api
# 期望输出: ELF 64-bit LSB executable, x86-64

cd ../..
```

#### 2.2 编译user-service服务

```bash
echo "🔨 编译user-service服务..."
cd backend/user-service

# 下载依赖
go mod download

# 交叉编译 - 针对腾讯云SCF x86-64架构
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o bin/user-service .

# 验证架构
file bin/user-service
# 期望输出: ELF 64-bit LSB executable, x86-64

cd ../..
```

#### 2.3 编译notification-service服务

```bash
echo "🔨 编译notification-service服务..."
cd backend/notification-service

# 下载依赖
go mod download

# 交叉编译 - 针对腾讯云SCF x86-64架构
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o bin/notification-service .

# 验证架构
file bin/notification-service
# 期望输出: ELF 64-bit LSB executable, x86-64

cd ../..
```

### 🐳 Docker镜像制作

#### 3.1 准备Dockerfile

为每个服务创建Dockerfile（如果不存在）：

**后端服务Dockerfile示例** (backend/website-api/Dockerfile):
```dockerfile
# 多阶段构建 - 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git ca-certificates tzdata

# 复制go mod文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 交叉编译 - 针对腾讯云SCF x86-64架构
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o main .

# 运行阶段
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
ENV TZ=Asia/Shanghai

# 创建非root用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app
COPY --from=builder /app/main .
RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["./main"]
```

**前端Dockerfile示例** (frontend/Dockerfile):
```dockerfile
# 多阶段构建 - 构建阶段
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# 运行阶段
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf 2>/dev/null || true

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### 3.2 构建镜像

```bash
# 构建后端服务镜像
docker build --platform linux/amd64 -t website-api:latest -f backend/website-api/Dockerfile backend/website-api
docker build --platform linux/amd64 -t user-service:latest -f backend/user-service/Dockerfile backend/user-service
docker build --platform linux/amd64 -t notification-service:latest -f backend/notification-service/Dockerfile backend/notification-service

# 构建前端镜像
docker build --platform linux/amd64 -t frontend:latest -f frontend/Dockerfile frontend
```

#### 3.3 验证镜像

```bash
# 查看构建的镜像
docker images

# 验证镜像架构
docker inspect website-api:latest | grep Architecture
# 期望输出: "Architecture": "amd64"

# 测试运行（可选）
docker run --rm -p 8080:8080 website-api:latest
```

## ✅ 验证构建结果

### 检查文件架构
```bash
# 检查Go二进制文件
file backend/*/bin/*
# 所有文件都应显示: ELF 64-bit LSB executable, x86-64

# 检查Docker镜像架构
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

### 构建统计
```bash
# 前端构建大小
du -sh frontend/dist/

# 后端二进制文件大小
ls -lh backend/*/bin/*

# Docker镜像大小
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

## 🚨 常见问题

参考 [troubleshooting.md](./troubleshooting.md) 了解构建过程中的常见问题和解决方案。

## 📝 下一步

构建完成后，继续进行 [第四步: 测试环境部署](../04-test-deployment/README.md)。