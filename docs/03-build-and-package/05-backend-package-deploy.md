# 5️⃣ 后端打包发布

## 📋 概述

本文档介绍如何为生产环境打包后端服务，包括Docker镜像制作、容器化配置、镜像优化和容器注册表推送等步骤。

## 🛠️ 前置条件

### 环境要求
- 完成后端编译和单元测试
- 完成本地联合调试
- Docker Desktop 已安装并运行
- 腾讯云CCR/TCR访问权限

### 验证前置条件
```bash
# 检查Docker环境
docker --version
docker info

# 检查后端二进制文件
find backend/ -name "*-linux" -exec ls -la {} \;

# 检查腾讯云CLI（如果使用）
tccli --version
```

## 🐳 Docker镜像制作

### 1. 基础镜像选择

#### 多阶段构建Dockerfile模板
```dockerfile
# backend/user-service/Dockerfile
# 第一阶段：构建阶段
FROM golang:1.19-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要的工具
RUN apk add --no-cache git ca-certificates tzdata

# 复制go mod文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 交叉编译
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -X main.version=${VERSION:-dev} -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o bin/user-service ./cmd/main.go

# 第二阶段：运行阶段
FROM alpine:3.18

# 安装运行时依赖
RUN apk add --no-cache ca-certificates tzdata curl

# 创建非root用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/bin/user-service /app/user-service

# 复制配置文件（如果有）
COPY --from=builder /app/configs/ /app/configs/

# 设置文件权限
RUN chown -R appuser:appgroup /app
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# 暴露端口
EXPOSE 8081

# 启动命令
CMD ["./user-service"]
```

### 2. 优化的Dockerfile配置

#### User Service Dockerfile
```dockerfile
# backend/user-service/Dockerfile
FROM alpine:3.18

# 镜像元数据
LABEL maintainer="your-email@example.com"
LABEL version="1.0.0"
LABEL description="User Service for Oh I Have That"

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    && rm -rf /var/cache/apk/*

# 设置时区
ENV TZ=Asia/Shanghai

# 创建应用用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# 创建应用目录
WORKDIR /app

# 复制预编译的二进制文件
COPY bin/user-service-linux /app/user-service

# 复制配置文件
COPY configs/ /app/configs/

# 设置权限
RUN chown -R appuser:appgroup /app && \
    chmod +x /app/user-service

# 切换到非root用户
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# 暴露端口
EXPOSE 8081

# 启动命令
ENTRYPOINT ["./user-service"]
CMD ["--config", "configs/production.yaml"]
```

#### Notification Service Dockerfile
```dockerfile
# backend/notification-service/Dockerfile
FROM alpine:3.18

LABEL maintainer="your-email@example.com"
LABEL version="1.0.0"
LABEL description="Notification Service for Oh I Have That"

RUN apk add --no-cache ca-certificates tzdata curl && \
    rm -rf /var/cache/apk/*

ENV TZ=Asia/Shanghai

RUN addgroup -g 1002 -S appgroup && \
    adduser -u 1002 -S appuser -G appgroup

WORKDIR /app

COPY bin/notification-service-linux /app/notification-service
COPY configs/ /app/configs/

RUN chown -R appuser:appgroup /app && \
    chmod +x /app/notification-service

USER appuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8082/health || exit 1

EXPOSE 8082

ENTRYPOINT ["./notification-service"]
CMD ["--config", "configs/production.yaml"]
```

#### Website API Dockerfile
```dockerfile
# backend/website-api/Dockerfile
FROM alpine:3.18

LABEL maintainer="your-email@example.com"
LABEL version="1.0.0"
LABEL description="Website API for Oh I Have That"

RUN apk add --no-cache ca-certificates tzdata curl && \
    rm -rf /var/cache/apk/*

ENV TZ=Asia/Shanghai

RUN addgroup -g 1003 -S appgroup && \
    adduser -u 1003 -S appuser -G appgroup

WORKDIR /app

COPY bin/website-api-linux /app/website-api
COPY configs/ /app/configs/
COPY static/ /app/static/

RUN chown -R appuser:appgroup /app && \
    chmod +x /app/website-api

USER appuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["./website-api"]
CMD ["--config", "configs/production.yaml"]
```

### 3. 构建Docker镜像

#### 单个服务构建
```bash
# 构建User Service镜像
cd backend/user-service
docker build --platform linux/amd64 -t user-service:latest .

# 构建Notification Service镜像
cd backend/notification-service
docker build --platform linux/amd64 -t notification-service:latest .

# 构建Website API镜像
cd backend/website-api
docker build --platform linux/amd64 -t website-api:latest .
```

#### 批量构建脚本
```bash
#!/bin/bash
# scripts/03-build-and-package/build-docker-images.sh

set -e

VERSION=${1:-latest}
REGISTRY=${2:-""}

echo "=== 构建Docker镜像 ==="
echo "版本: $VERSION"
echo "注册表: $REGISTRY"

# 服务列表
SERVICES=("user-service" "notification-service" "website-api")

for service in "${SERVICES[@]}"; do
    echo "构建 $service 镜像..."
    
    cd "backend/$service"
    
    # 构建镜像
    if [ -n "$REGISTRY" ]; then
        IMAGE_NAME="$REGISTRY/$service:$VERSION"
    else
        IMAGE_NAME="$service:$VERSION"
    fi
    
    docker build \
        --platform linux/amd64 \
        --build-arg VERSION="$VERSION" \
        --build-arg BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        -t "$IMAGE_NAME" \
        .
    
    echo "✅ $service 镜像构建完成: $IMAGE_NAME"
    
    cd ../..
done

echo "=== 所有镜像构建完成 ==="
```

## 🔧 容器化配置

### 1. 生产环境配置

#### 配置文件模板
```yaml
# backend/user-service/configs/production.yaml
server:
  host: "0.0.0.0"
  port: 8081
  read_timeout: 30s
  write_timeout: 30s
  idle_timeout: 60s

database:
  host: "${DB_HOST}"
  port: "${DB_PORT}"
  username: "${DB_USERNAME}"
  password: "${DB_PASSWORD}"
  database: "${DB_NAME}"
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: 300s

redis:
  host: "${REDIS_HOST}"
  port: "${REDIS_PORT}"
  password: "${REDIS_PASSWORD}"
  db: 0
  pool_size: 10

logging:
  level: "info"
  format: "json"
  output: "stdout"

metrics:
  enabled: true
  port: 9091
  path: "/metrics"

tracing:
  enabled: true
  jaeger_endpoint: "${JAEGER_ENDPOINT}"
  service_name: "user-service"
```

### 2. Docker Compose配置

#### 开发环境Docker Compose
```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  user-service:
    build:
      context: ./backend/user-service
      dockerfile: Dockerfile
    ports:
      - "8081:8081"
      - "9091:9091"  # metrics
    environment:
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_USERNAME=root
      - DB_PASSWORD=password
      - DB_NAME=ohihavethat
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      - mysql
      - redis
    networks:
      - app-network

  notification-service:
    build:
      context: ./backend/notification-service
      dockerfile: Dockerfile
    ports:
      - "8082:8082"
      - "9092:9092"  # metrics
    environment:
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_USERNAME=root
      - DB_PASSWORD=password
      - DB_NAME=ohihavethat
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      - mysql
      - redis
    networks:
      - app-network

  website-api:
    build:
      context: ./backend/website-api
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
      - "9090:9090"  # metrics
    environment:
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_USERNAME=root
      - DB_PASSWORD=password
      - DB_NAME=ohihavethat
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - USER_SERVICE_URL=http://user-service:8081
      - NOTIFICATION_SERVICE_URL=http://notification-service:8082
    depends_on:
      - mysql
      - redis
      - user-service
      - notification-service
    networks:
      - app-network

  mysql:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=password
      - MYSQL_DATABASE=ohihavethat
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - app-network

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
    networks:
      - app-network

volumes:
  mysql_data:

networks:
  app-network:
    driver: bridge
```

## 📦 镜像优化

### 1. 镜像大小优化

#### 多阶段构建优化
```dockerfile
# 优化的多阶段构建
FROM golang:1.19-alpine AS builder

# 使用构建缓存
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# 先复制go.mod，利用Docker层缓存
COPY go.mod go.sum ./
RUN go mod download

# 再复制源代码
COPY . .

# 优化构建参数
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -a -installsuffix cgo \
    -ldflags="-s -w -extldflags '-static'" \
    -o app ./cmd/main.go

# 使用distroless基础镜像
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /app/app /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

EXPOSE 8080
USER nonroot:nonroot

ENTRYPOINT ["/app"]
```

#### .dockerignore文件
```bash
# backend/user-service/.dockerignore
.git
.gitignore
README.md
Dockerfile
.dockerignore
bin/
tests/
*.test
*.prof
.env*
node_modules/
coverage/
.nyc_output/
```

### 2. 安全优化

#### 安全扫描
```bash
# 使用Trivy扫描镜像安全漏洞
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image user-service:latest

# 使用Docker Scout扫描
docker scout cves user-service:latest
```

#### 安全最佳实践
```dockerfile
# 安全优化的Dockerfile
FROM alpine:3.18

# 更新包管理器并安装安全更新
RUN apk update && apk upgrade && \
    apk add --no-cache ca-certificates tzdata curl && \
    rm -rf /var/cache/apk/*

# 创建非特权用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup -s /bin/sh

# 设置安全的文件权限
WORKDIR /app
COPY --chown=appuser:appgroup bin/app /app/app
RUN chmod 755 /app/app

# 使用非root用户运行
USER appuser

# 设置只读根文件系统
# 在运行时使用: docker run --read-only --tmpfs /tmp user-service:latest
```

## 🚀 容器注册表推送

### 1. 腾讯云CCR推送

#### 登录CCR
```bash
# 登录腾讯云CCR个人版
docker login ccr.ccs.tencentyun.com --username=your-username

# 或使用临时密码
docker login ccr.ccs.tencentyun.com --username=your-username --password-stdin
```

#### 标记和推送镜像
```bash
#!/bin/bash
# scripts/deploy/push-to-ccr.sh

set -e

REGISTRY="ccr.ccs.tencentyun.com/your-namespace"
VERSION=${1:-latest}

SERVICES=("user-service" "notification-service" "website-api")

echo "=== 推送镜像到腾讯云CCR ==="

for service in "${SERVICES[@]}"; do
    echo "处理 $service..."
    
    # 标记镜像
    docker tag "$service:$VERSION" "$REGISTRY/$service:$VERSION"
    docker tag "$service:$VERSION" "$REGISTRY/$service:latest"
    
    # 推送镜像
    echo "推送 $service:$VERSION..."
    docker push "$REGISTRY/$service:$VERSION"
    
    echo "推送 $service:latest..."
    docker push "$REGISTRY/$service:latest"
    
    echo "✅ $service 推送完成"
done

echo "=== 所有镜像推送完成 ==="
```

### 2. 镜像版本管理

#### 语义化版本标记
```bash
#!/bin/bash
# scripts/deploy/tag-images.sh

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "用法: $0 <version>"
    echo "示例: $0 1.2.3"
    exit 1
fi

REGISTRY="ccr.ccs.tencentyun.com/your-namespace"
SERVICES=("user-service" "notification-service" "website-api")

# 验证版本格式
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误: 版本格式不正确，应为 x.y.z"
    exit 1
fi

# 提取主版本和次版本
MAJOR_VERSION=$(echo $VERSION | cut -d. -f1)
MINOR_VERSION=$(echo $VERSION | cut -d. -f1-2)

echo "=== 标记镜像版本 ==="
echo "完整版本: $VERSION"
echo "次版本: $MINOR_VERSION"
echo "主版本: $MAJOR_VERSION"

for service in "${SERVICES[@]}"; do
    echo "标记 $service..."
    
    # 标记完整版本
    docker tag "$service:latest" "$REGISTRY/$service:$VERSION"
    docker tag "$service:latest" "$REGISTRY/$service:v$VERSION"
    
    # 标记次版本
    docker tag "$service:latest" "$REGISTRY/$service:$MINOR_VERSION"
    docker tag "$service:latest" "$REGISTRY/$service:v$MINOR_VERSION"
    
    # 标记主版本
    docker tag "$service:latest" "$REGISTRY/$service:$MAJOR_VERSION"
    docker tag "$service:latest" "$REGISTRY/$service:v$MAJOR_VERSION"
    
    echo "✅ $service 版本标记完成"
done

echo "=== 版本标记完成 ==="
```

## 🔍 部署验证

### 1. 镜像验证脚本

```bash
#!/bin/bash
# scripts/deploy/verify-images.sh

set -e

REGISTRY="ccr.ccs.tencentyun.com/your-namespace"
VERSION=${1:-latest}

SERVICES=("user-service" "notification-service" "website-api")

echo "=== 验证Docker镜像 ==="

for service in "${SERVICES[@]}"; do
    IMAGE="$REGISTRY/$service:$VERSION"
    
    echo "验证 $IMAGE..."
    
    # 1. 检查镜像是否存在
    if docker manifest inspect "$IMAGE" > /dev/null 2>&1; then
        echo "✅ 镜像存在: $IMAGE"
    else
        echo "❌ 镜像不存在: $IMAGE"
        continue
    fi
    
    # 2. 运行容器测试
    echo "测试容器启动..."
    CONTAINER_ID=$(docker run -d --rm \
        -e DB_HOST=localhost \
        -e DB_PORT=3306 \
        -e DB_USERNAME=test \
        -e DB_PASSWORD=test \
        -e DB_NAME=test \
        "$IMAGE" --help 2>/dev/null || echo "failed")
    
    if [ "$CONTAINER_ID" != "failed" ]; then
        echo "✅ 容器启动成功"
        docker stop "$CONTAINER_ID" > /dev/null 2>&1 || true
    else
        echo "⚠️  容器启动测试跳过（需要数据库连接）"
    fi
    
    # 3. 检查镜像大小
    SIZE=$(docker images "$IMAGE" --format "table {{.Size}}" | tail -n 1)
    echo "📦 镜像大小: $SIZE"
    
    # 4. 安全扫描（如果安装了trivy）
    if command -v trivy &> /dev/null; then
        echo "🔍 安全扫描..."
        trivy image --severity HIGH,CRITICAL --quiet "$IMAGE" || echo "⚠️  发现安全问题"
    fi
    
    echo ""
done

echo "=== 镜像验证完成 ==="
```

### 2. 端到端部署测试

```bash
#!/bin/bash
# scripts/deploy/e2e-deployment-test.sh

set -e

REGISTRY="ccr.ccs.tencentyun.com/your-namespace"
VERSION=${1:-latest}

echo "=== 端到端部署测试 ==="

# 1. 创建测试网络
docker network create test-network 2>/dev/null || true

# 2. 启动依赖服务
echo "启动测试数据库..."
docker run -d --name test-mysql --network test-network \
    -e MYSQL_ROOT_PASSWORD=testpass \
    -e MYSQL_DATABASE=testdb \
    mysql:8.0

docker run -d --name test-redis --network test-network \
    redis:alpine

# 等待数据库启动
echo "等待数据库启动..."
sleep 30

# 3. 启动应用服务
echo "启动应用服务..."

# User Service
docker run -d --name test-user-service --network test-network \
    -e DB_HOST=test-mysql \
    -e DB_PORT=3306 \
    -e DB_USERNAME=root \
    -e DB_PASSWORD=testpass \
    -e DB_NAME=testdb \
    -e REDIS_HOST=test-redis \
    -e REDIS_PORT=6379 \
    "$REGISTRY/user-service:$VERSION"

# Notification Service
docker run -d --name test-notification-service --network test-network \
    -e DB_HOST=test-mysql \
    -e DB_PORT=3306 \
    -e DB_USERNAME=root \
    -e DB_PASSWORD=testpass \
    -e DB_NAME=testdb \
    -e REDIS_HOST=test-redis \
    -e REDIS_PORT=6379 \
    "$REGISTRY/notification-service:$VERSION"

# Website API
docker run -d --name test-website-api --network test-network \
    -p 8080:8080 \
    -e DB_HOST=test-mysql \
    -e DB_PORT=3306 \
    -e DB_USERNAME=root \
    -e DB_PASSWORD=testpass \
    -e DB_NAME=testdb \
    -e REDIS_HOST=test-redis \
    -e REDIS_PORT=6379 \
    -e USER_SERVICE_URL=http://test-user-service:8081 \
    -e NOTIFICATION_SERVICE_URL=http://test-notification-service:8082 \
    "$REGISTRY/website-api:$VERSION"

# 4. 等待服务启动
echo "等待服务启动..."
sleep 20

# 5. 健康检查
echo "执行健康检查..."
for i in {1..30}; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ 健康检查通过"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "❌ 健康检查失败"
        docker logs test-website-api
        exit 1
    fi
    
    sleep 2
done

# 6. API测试
echo "执行API测试..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/info)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ API测试通过"
else
    echo "❌ API测试失败，HTTP状态码: $HTTP_CODE"
fi

# 7. 清理测试环境
cleanup() {
    echo "清理测试环境..."
    docker stop test-website-api test-notification-service test-user-service test-redis test-mysql 2>/dev/null || true
    docker rm test-website-api test-notification-service test-user-service test-redis test-mysql 2>/dev/null || true
    docker network rm test-network 2>/dev/null || true
}

trap cleanup EXIT

echo "=== 端到端部署测试完成 ==="
```

## 🚀 自动化部署脚本

```bash
#!/bin/bash
# scripts/03-build-and-package/build-and-deploy-backend.sh

set -e

VERSION=${1:-$(date +%Y%m%d-%H%M%S)}
REGISTRY=${2:-"ccr.ccs.tencentyun.com/your-namespace"}
PUSH=${3:-false}

echo "=== 后端打包发布自动化脚本 ==="
echo "版本: $VERSION"
echo "注册表: $REGISTRY"
echo "推送: $PUSH"

# 1. 编译后端服务
echo "1. 编译后端服务..."
./scripts/03-build-and-package/build-backend.sh --all

# 2. 运行测试
echo "2. 运行测试..."
./scripts/03-build-and-package/build-backend.sh --test-only

# 3. 构建Docker镜像
echo "3. 构建Docker镜像..."
./scripts/03-build-and-package/build-docker-images.sh "$VERSION" "$REGISTRY"

# 4. 镜像安全扫描
echo "4. 镜像安全扫描..."
if command -v trivy &> /dev/null; then
    for service in user-service notification-service website-api; do
        echo "扫描 $service..."
        trivy image --severity HIGH,CRITICAL "$REGISTRY/$service:$VERSION" || echo "⚠️  发现安全问题"
    done
else
    echo "⚠️  Trivy未安装，跳过安全扫描"
fi

# 5. 推送镜像（如果指定）
if [ "$PUSH" = "true" ]; then
    echo "5. 推送镜像到注册表..."
    ./scripts/deploy/push-to-ccr.sh "$VERSION"
    
    echo "6. 验证推送的镜像..."
    ./scripts/deploy/verify-images.sh "$VERSION"
    
    echo "7. 端到端部署测试..."
    ./scripts/deploy/e2e-deployment-test.sh "$VERSION"
fi

echo "=== 后端打包发布完成 ==="
echo "镜像版本: $VERSION"
echo "镜像列表:"
for service in user-service notification-service website-api; do
    echo "  - $REGISTRY/$service:$VERSION"
done
```

## ✅ 验证清单

- [ ] Dockerfile配置优化完成
- [ ] 多阶段构建配置正确
- [ ] 镜像安全配置完成
- [ ] 容器化配置完成
- [ ] Docker Compose配置完成
- [ ] 镜像构建成功
- [ ] 镜像大小优化完成
- [ ] 安全扫描通过
- [ ] 容器注册表推送成功
- [ ] 版本标记正确
- [ ] 部署验证通过

## 📝 下一步

后端打包发布完成后，所有编译和打包工作已完成。接下来可以进行 [第四步: 测试环境部署](../04-test-deployment/README.md)。