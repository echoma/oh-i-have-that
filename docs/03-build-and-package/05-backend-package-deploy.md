# 5️⃣ 后端打包发布

## 📋 概述

本文档介绍如何为生产环境打包后端服务，包括Go程序编译、Docker镜像构建、容器注册表推送等步骤。

## 🛠️ 前置条件

### 环境要求
- 完成后端编译和单元测试
- 完成本地联合调试
- Go >= 1.19
- Docker >= 20.10
- 腾讯云CCR访问权限

### 验证前置条件
```bash
# 检查Go环境
go version

# 检查Docker环境
docker --version

# 检查后端服务构建状态
ls -la backend/*/bin/
```

## 🚀 使用自动化脚本

项目提供了完善的后端构建和Docker镜像构建脚本。

### 后端服务构建

```bash
# 构建所有后端服务
./scripts/03-build-and-package/build-backend.sh

# 构建特定服务
./scripts/03-build-and-package/build-backend.sh --service=user-service

# 生产环境构建（交叉编译）
./scripts/03-build-and-package/build-backend.sh --prod

# 清理后重新构建
./scripts/03-build-and-package/build-backend.sh --clean

# 查看所有可用选项
./scripts/03-build-and-package/build-backend.sh --help
```

### Docker镜像构建

```bash
# 构建所有Docker镜像
./scripts/03-build-and-package/build-docker-images.sh

# 构建特定服务镜像
./scripts/03-build-and-package/build-docker-images.sh --service=user-service

# 构建并推送到注册表
./scripts/03-build-and-package/build-docker-images.sh --push

# 构建多架构镜像
./scripts/03-build-and-package/build-docker-images.sh --multi-arch

# 查看所有可用选项
./scripts/03-build-and-package/build-docker-images.sh --help
```

### 完整构建流程

```bash
# 使用完整构建脚本（包含前端+后端+Docker）
./scripts/03-build-and-package/build-all.sh

# 仅构建后端和Docker
./scripts/03-build-and-package/build-all.sh --skip-frontend

# 查看所有可用选项
./scripts/03-build-and-package/build-all.sh --help
```

## 🏗️ 生产环境配置

### 1. 环境变量配置

为每个后端服务创建生产环境配置：

```bash
# user-service 生产配置
cat > backend/user-service/.env.production << EOF
# 数据库配置
DB_HOST=your-db-host.com
DB_PORT=5432
DB_NAME=userdb_prod
DB_USER=prod_user
DB_PASSWORD=your-secure-password

# Redis配置
REDIS_HOST=your-redis-host.com
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password

# 服务配置
PORT=8080
LOG_LEVEL=info
JWT_SECRET=your-jwt-secret

# 外部服务
NOTIFICATION_SERVICE_URL=http://notification-service:8081
EOF

# notification-service 生产配置
cat > backend/notification-service/.env.production << EOF
# 数据库配置
DB_HOST=your-db-host.com
DB_PORT=5432
DB_NAME=notificationdb_prod
DB_USER=prod_user
DB_PASSWORD=your-secure-password

# 消息队列配置
MQ_HOST=your-mq-host.com
MQ_PORT=5672
MQ_USER=prod_mq_user
MQ_PASSWORD=your-mq-password

# 服务配置
PORT=8081
LOG_LEVEL=info

# 第三方服务
EMAIL_PROVIDER_API_KEY=your-email-api-key
SMS_PROVIDER_API_KEY=your-sms-api-key
EOF

# website-api 生产配置
cat > backend/website-api/.env.production << EOF
# 服务配置
PORT=8082
LOG_LEVEL=info

# 上游服务
USER_SERVICE_URL=http://user-service:8080
NOTIFICATION_SERVICE_URL=http://notification-service:8081

# 静态文件配置
STATIC_FILES_PATH=/app/static
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
EOF
```

### 2. 构建配置优化

Go构建优化配置：

```bash
# 生产环境构建标志
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64

# 优化构建参数
GO_BUILD_FLAGS="-a -installsuffix cgo -ldflags '-w -s -extldflags \"-static\"'"
```

## 📦 Docker镜像优化

### 1. 多阶段构建

构建脚本已使用多阶段构建优化镜像大小：

```dockerfile
# 示例：优化的Dockerfile结构
FROM golang:1.19-alpine AS builder
# 构建阶段...

FROM alpine:latest AS runtime
# 运行时阶段，仅包含必要文件
```

### 2. 镜像安全配置

```bash
# 扫描镜像安全漏洞（如果安装了扫描工具）
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image your-registry/user-service:latest

# 检查镜像大小
docker images | grep your-registry
```

## 🌐 容器注册表配置

### 1. 腾讯云CCR配置

```bash
# 登录CCR
docker login ccr.ccs.tencentyun.com --username=your-username

# 配置镜像标签
export REGISTRY_URL="ccr.ccs.tencentyun.com/your-namespace"
export IMAGE_TAG="v1.0.0"

# 标记和推送镜像
docker tag user-service:latest $REGISTRY_URL/user-service:$IMAGE_TAG
docker push $REGISTRY_URL/user-service:$IMAGE_TAG
```

### 2. 镜像版本管理

```bash
# 使用Git提交hash作为标签
GIT_COMMIT=$(git rev-parse --short HEAD)
docker tag user-service:latest $REGISTRY_URL/user-service:$GIT_COMMIT

# 使用语义化版本
VERSION=$(git describe --tags --abbrev=0)
docker tag user-service:latest $REGISTRY_URL/user-service:$VERSION
```

## 🚀 部署准备

### 1. 健康检查配置

为每个服务添加健康检查端点：

```go
// 示例：健康检查处理器
func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
    health := map[string]interface{}{
        "status": "healthy",
        "timestamp": time.Now().Unix(),
        "version": os.Getenv("APP_VERSION"),
        "uptime": time.Since(startTime).Seconds(),
    }
    
    // 检查数据库连接
    if err := db.Ping(); err != nil {
        health["status"] = "unhealthy"
        health["database"] = "disconnected"
        w.WriteHeader(http.StatusServiceUnavailable)
    }
    
    json.NewEncoder(w).Encode(health)
}
```

### 2. 配置文件管理

```bash
# 创建配置文件模板
mkdir -p config/production

# user-service 配置
cat > config/production/user-service.yaml << EOF
server:
  port: 8080
  read_timeout: 30s
  write_timeout: 30s

database:
  host: \${DB_HOST}
  port: \${DB_PORT}
  name: \${DB_NAME}
  user: \${DB_USER}
  password: \${DB_PASSWORD}
  max_connections: 100
  max_idle: 10

redis:
  host: \${REDIS_HOST}
  port: \${REDIS_PORT}
  password: \${REDIS_PASSWORD}
  db: 0

logging:
  level: \${LOG_LEVEL}
  format: json
  output: stdout
EOF
```

## 📊 监控和日志

### 1. 应用监控配置

```go
// 示例：Prometheus指标配置
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "HTTP request duration in seconds",
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
    prometheus.MustRegister(httpRequestDuration)
}

// 在main函数中添加metrics端点
http.Handle("/metrics", promhttp.Handler())
```

### 2. 结构化日志配置

```go
// 示例：结构化日志配置
import (
    "github.com/sirupsen/logrus"
)

func setupLogging() {
    logrus.SetFormatter(&logrus.JSONFormatter{})
    
    level, err := logrus.ParseLevel(os.Getenv("LOG_LEVEL"))
    if err != nil {
        level = logrus.InfoLevel
    }
    logrus.SetLevel(level)
    
    logrus.WithFields(logrus.Fields{
        "service": "user-service",
        "version": os.Getenv("APP_VERSION"),
    }).Info("Service starting")
}
```

## 🚀 完整部署流程

### 自动化部署脚本

```bash
#!/bin/bash
# deploy-backend.sh

set -e

echo "=== 后端完整部署流程 ==="

# 1. 后端服务构建
echo "1. 构建后端服务..."
./scripts/03-build-and-package/build-backend.sh --clean --prod

# 2. Docker镜像构建
echo "2. 构建Docker镜像..."
./scripts/03-build-and-package/build-docker-images.sh --clean

# 3. 镜像推送到注册表
if [ "$PUSH_TO_REGISTRY" = "true" ]; then
    echo "3. 推送镜像到注册表..."
    ./scripts/03-build-and-package/build-docker-images.sh --push
fi

# 4. 验证镜像
echo "4. 验证镜像..."
for service in user-service notification-service website-api; do
    if docker images | grep -q "$service"; then
        echo "✅ $service 镜像构建成功"
        docker images | grep "$service"
    else
        echo "❌ $service 镜像构建失败"
        exit 1
    fi
done

echo "=== 后端部署准备完成 ==="
```

### 部署验证脚本

```bash
#!/bin/bash
# verify-backend-deployment.sh

set -e

echo "=== 验证后端部署 ==="

SERVICES=("user-service:8080" "notification-service:8081" "website-api:8082")

for service_port in "${SERVICES[@]}"; do
    service=$(echo $service_port | cut -d: -f1)
    port=$(echo $service_port | cut -d: -f2)
    
    echo "检查 $service..."
    
    # 检查健康状态
    if curl -f -s "http://localhost:$port/health" > /dev/null; then
        echo "✅ $service 健康检查通过"
    else
        echo "❌ $service 健康检查失败"
    fi
    
    # 检查metrics端点
    if curl -f -s "http://localhost:$port/metrics" > /dev/null; then
        echo "✅ $service metrics端点正常"
    else
        echo "⚠️  $service metrics端点异常"
    fi
done

echo "=== 后端验证完成 ==="
```

## 🐛 常见问题

### 构建失败
```bash
# 清理Go模块缓存
go clean -modcache

# 重新下载依赖
cd backend/user-service && go mod download

# 重新构建
./scripts/03-build-and-package/build-backend.sh --clean
```

### Docker构建失败
```bash
# 清理Docker缓存
docker system prune -f

# 重新构建镜像
./scripts/03-build-and-package/build-docker-images.sh --clean --no-cache
```

### 镜像推送失败
```bash
# 重新登录注册表
docker login ccr.ccs.tencentyun.com

# 检查网络连接
ping ccr.ccs.tencentyun.com

# 重试推送
./scripts/03-build-and-package/build-docker-images.sh --push --retry
```

## ✅ 验证清单

- [ ] 后端服务构建成功
- [ ] Docker镜像构建成功
- [ ] 镜像大小合理（< 50MB per service）
- [ ] 健康检查端点正常
- [ ] 监控指标端点正常
- [ ] 配置文件准备完成
- [ ] 镜像推送到注册表成功
- [ ] 部署脚本准备完成

## 📝 下一步

后端打包发布完成后，可以进行：

1. [基础设施部署](../04-test-deployment/README.md)
2. [生产环境部署](../05-production-deployment/README.md)
3. [监控和日志配置](./monitoring-setup.md)

## 🔗 相关文档

- [后端构建脚本源码](../../scripts/03-build-and-package/build-backend.sh)
- [Docker镜像构建脚本源码](../../scripts/03-build-and-package/build-docker-images.sh)
- [完整构建脚本源码](../../scripts/03-build-and-package/build-all.sh)
- [本地联合调试](./03-local-integration-debug.md)
- [故障排除指南](./troubleshooting.md)