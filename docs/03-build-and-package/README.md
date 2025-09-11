# 🔨 第三步: 编译及镜像制作

本文档详细说明如何构建前端应用、编译后端服务并制作Docker镜像。

## 🎯 目标

- 构建前端静态资源
- 编译后端Go服务
- 制作Docker镜像
- 推送镜像到容器注册表

## 📋 前置条件

- 完成 [第二步: 基础设施搭建](../02-infrastructure-setup/README.md)
- 基础设施部署成功
- 容器注册表可用

## 🚀 自动化构建（推荐）

使用我们提供的自动化脚本来简化构建和打包过程：

```bash
# 1. 构建前端
./scripts/03-build-and-package/build-frontend.sh

# 2. 构建后端
./scripts/03-build-and-package/build-backend.sh

# 3. 构建Docker镜像
./scripts/03-build-and-package/build-docker-images.sh
```

### 📋 脚本详细说明

#### 1. build-frontend.sh - 前端构建
**功能**: 构建前端静态资源
- 自动检测Node.js环境
- 安装前端依赖（如需要）
- 执行前端构建
- 显示构建统计信息
- 验证构建结果

**使用方法**:
```bash
# 基本构建
./scripts/03-build-and-package/build-frontend.sh

# 构建前会自动安装依赖
# 支持 dist/ 和 build/ 输出目录
```

#### 2. build-backend.sh - 后端构建
**功能**: 编译所有Go后端服务
- 检测Go环境
- 批量编译所有后端服务
- 交叉编译支持（Linux/amd64）
- 显示编译结果和文件大小
- 验证可执行文件

**使用方法**:
```bash
# 构建所有后端服务
./scripts/03-build-and-package/build-backend.sh

# 会自动编译：
# - website-api
# - user-service  
# - notification-service
```

#### 3. build-docker-images.sh - Docker镜像构建
**功能**: 构建和推送Docker镜像
- 检测Docker环境
- 批量构建所有服务镜像
- 支持镜像标签管理
- 支持推送到容器注册表
- 显示镜像大小和构建统计

**使用方法**:
```bash
# 基本构建（本地镜像）
./scripts/03-build-and-package/build-docker-images.sh

# 指定镜像标签
./scripts/03-build-and-package/build-docker-images.sh --tag=v1.0.0

# 构建并推送到注册表
./scripts/03-build-and-package/build-docker-images.sh \
  --registry=ccr.ccs.tencentyun.com/your-namespace \
  --tag=v1.0.0 \
  --push

# 不使用缓存构建
./scripts/03-build-and-package/build-docker-images.sh --no-cache

# 查看帮助
./scripts/03-build-and-package/build-docker-images.sh --help
```

## 🎨 手动前端应用构建（备选方案）

### 1.1 准备前端环境

```bash
# 进入前端目录
cd frontend

# 确保依赖已安装
npm install

# 检查package.json配置
cat package.json
```

### 1.2 构建前端应用

```bash
# 构建生产版本
npm run build

# 检查构建结果
ls -la dist/
du -sh dist/

# 验证构建文件
echo "=== 前端构建文件 ==="
find dist/ -type f -name "*.html" -o -name "*.css" -o -name "*.js"
```

### 1.3 测试前端构建

```bash
# 本地预览构建结果
npm run preview

# 或使用简单HTTP服务器
cd dist
python3 -m http.server 8000
# 访问 http://localhost:8000

cd ../..
```

## ⚙️ 后端服务编译

### 2.1 编译website-api服务

```bash
echo "🔨 编译 website-api 服务..."
cd backend/website-api

# 检查Go模块
go mod tidy
go mod verify

# 编译服务
go build -o website-api main.go

# 验证编译结果
ls -la website-api
file website-api

# 测试编译的程序
./website-api &
WEBSITE_API_PID=$!
sleep 2

# 测试API
curl http://localhost:8080/api/v1/health
kill $WEBSITE_API_PID

cd ../..
```

### 2.2 编译user-service服务

```bash
echo "🔨 编译 user-service 服务..."
cd backend/user-service

# 检查Go模块
go mod tidy
go mod verify

# 编译服务
go build -o user-service main.go

# 验证编译结果
ls -la user-service
file user-service

cd ../..
```

### 2.3 编译notification-service服务

```bash
echo "🔨 编译 notification-service 服务..."
cd backend/notification-service

# 检查Go模块
go mod tidy
go mod verify

# 编译服务
go build -o notification-service main.go

# 验证编译结果
ls -la notification-service
file notification-service

cd ../..
```

### 2.4 批量编译验证

```bash
# 使用Make命令批量构建（如果可用）
make build-backend

# 或手动验证所有服务
echo "=== 后端编译结果 ==="
for service in website-api user-service notification-service; do
    if [ -f "backend/$service/$service" ]; then
        echo "✅ $service: $(ls -lh backend/$service/$service | awk '{print $5}')"
    else
        echo "❌ $service: 编译失败"
    fi
done
```

## 🐳 Docker镜像制作

### 3.1 准备Docker环境

```bash
# 检查Docker状态
docker --version
docker info

# 检查Docker服务
docker ps
```

### 3.2 构建website-api镜像

```bash
echo "🐳 构建 website-api Docker镜像..."

# 检查Dockerfile
if [ -f "backend/website-api/Dockerfile" ]; then
    cat backend/website-api/Dockerfile
else
    echo "创建Dockerfile..."
    cat > backend/website-api/Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o website-api main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/website-api .
EXPOSE 8080
CMD ["./website-api"]
EOF
fi

# 构建镜像
cd backend/website-api
docker build -t oh-i-have-that/website-api:latest .
cd ../..

# 验证镜像
docker images | grep website-api
```

### 3.3 构建user-service镜像

```bash
echo "🐳 构建 user-service Docker镜像..."

# 检查或创建Dockerfile
if [ ! -f "backend/user-service/Dockerfile" ]; then
    cat > backend/user-service/Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o user-service main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/user-service .
EXPOSE 8080
CMD ["./user-service"]
EOF
fi

# 构建镜像
cd backend/user-service
docker build -t oh-i-have-that/user-service:latest .
cd ../..

# 验证镜像
docker images | grep user-service
```

### 3.4 构建notification-service镜像

```bash
echo "🐳 构建 notification-service Docker镜像..."

# 检查或创建Dockerfile
if [ ! -f "backend/notification-service/Dockerfile" ]; then
    cat > backend/notification-service/Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o notification-service main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/notification-service .
EXPOSE 8080
CMD ["./notification-service"]
EOF
fi

# 构建镜像
cd backend/notification-service
docker build -t oh-i-have-that/notification-service:latest .
cd ../..

# 验证镜像
docker images | grep notification-service
```

### 3.5 批量构建镜像

```bash
# 使用Make命令批量构建（如果可用）
make docker-build

# 查看所有构建的镜像
echo "=== Docker镜像构建结果 ==="
docker images | grep oh-i-have-that
```

## 📤 镜像推送

### 4.1 配置容器注册表认证

```bash
# 获取容器注册表信息
cd infrastructure
CONTAINER_REGISTRY_URL=$(terraform output -raw container_registry_url 2>/dev/null || echo '')
cd ..

if [ -n "$CONTAINER_REGISTRY_URL" ]; then
    echo "容器注册表URL: $CONTAINER_REGISTRY_URL"
    
    # 配置Docker登录
    echo "请配置Docker登录到腾讯云容器注册表"
    echo "1. 访问腾讯云控制台: https://console.cloud.tencent.com/tcr"
    echo "2. 获取登录命令并执行"
    echo "3. 示例: docker login --username=xxx --password=xxx xxx.tencentcloudcr.com"
else
    echo "⚠️  容器注册表未配置，跳过镜像推送"
fi
```

### 4.2 标记和推送镜像

```bash
if [ -n "$CONTAINER_REGISTRY_URL" ]; then
    echo "🚀 推送镜像到容器注册表..."
    
    # 标记镜像
    docker tag oh-i-have-that/website-api:latest $CONTAINER_REGISTRY_URL/website-api:latest
    docker tag oh-i-have-that/user-service:latest $CONTAINER_REGISTRY_URL/user-service:latest
    docker tag oh-i-have-that/notification-service:latest $CONTAINER_REGISTRY_URL/notification-service:latest
    
    # 推送镜像
    docker push $CONTAINER_REGISTRY_URL/website-api:latest
    docker push $CONTAINER_REGISTRY_URL/user-service:latest
    docker push $CONTAINER_REGISTRY_URL/notification-service:latest
    
    echo "✅ 镜像推送完成"
else
    echo "ℹ️  本地镜像构建完成，未推送到远程注册表"
fi
```

## 🧪 构建验证

### 5.1 测试Docker镜像

```bash
echo "🧪 测试Docker镜像..."

# 测试website-api镜像
echo "测试 website-api 镜像..."
docker run -d --name test-website-api -p 8081:8080 oh-i-have-that/website-api:latest
sleep 3

# 测试API
curl http://localhost:8081/api/v1/health
docker stop test-website-api
docker rm test-website-api

echo "✅ website-api 镜像测试通过"
```

### 5.2 验证前端资源

```bash
echo "🧪 验证前端资源..."

# 检查关键文件
if [ -f "frontend/dist/index.html" ]; then
    echo "✅ index.html 存在"
    head -5 frontend/dist/index.html
else
    echo "❌ index.html 不存在"
fi

# 检查静态资源
echo "静态资源文件:"
find frontend/dist -name "*.css" -o -name "*.js" | head -5
```

### 5.3 构建大小检查

```bash
echo "📊 构建大小统计..."

# 前端构建大小
echo "前端构建大小:"
du -sh frontend/dist/

# 后端二进制大小
echo "后端二进制大小:"
for service in website-api user-service notification-service; do
    if [ -f "backend/$service/$service" ]; then
        echo "$service: $(du -sh backend/$service/$service | cut -f1)"
    fi
done

# Docker镜像大小
echo "Docker镜像大小:"
docker images | grep oh-i-have-that | awk '{print $1":"$2" - "$7$8}'
```

## 📋 完成检查清单

- [ ] 前端应用构建成功
- [ ] 前端dist目录包含所有必需文件
- [ ] website-api服务编译成功
- [ ] user-service服务编译成功  
- [ ] notification-service服务编译成功
- [ ] 所有Docker镜像构建成功
- [ ] Docker镜像可正常运行
- [ ] 镜像推送到容器注册表（如果配置）
- [ ] 构建大小合理

## 🔧 优化建议

### 构建优化

```bash
# Go编译优化
go build -ldflags="-s -w" -o service main.go

# Docker镜像优化
# 使用多阶段构建
# 使用更小的基础镜像（如alpine）
# 清理不必要的文件
```

### 缓存优化

```bash
# Docker构建缓存
docker builder prune

# Go模块缓存
go clean -modcache
```

## 🆘 故障排除

遇到问题请查看: [编译及镜像制作故障排除](troubleshooting.md)

---

**✅ 编译及镜像制作完成！**

下一步: [04-test-deployment](../04-test-deployment/README.md)