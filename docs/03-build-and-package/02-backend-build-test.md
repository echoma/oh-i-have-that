# 2️⃣ 后端编译及单元测试

## 📋 概述

本文档介绍如何编译后端Go服务并执行单元测试。项目包含多个微服务，需要进行交叉编译以确保在腾讯云SCF环境中正确运行。

## 🛠️ 前置条件

### 环境要求
- Go >= 1.19
- Git
- Make（可选，用于Makefile）

### 验证环境
```bash
go version
git --version
```

## 📁 项目结构

```
backend/
├── user-service/          # 用户服务
│   ├── cmd/
│   ├── internal/
│   ├── pkg/
│   ├── tests/
│   ├── go.mod
│   ├── go.sum
│   └── Dockerfile
├── notification-service/  # 通知服务
│   ├── cmd/
│   ├── internal/
│   ├── pkg/
│   ├── tests/
│   ├── go.mod
│   ├── go.sum
│   └── Dockerfile
└── website-api/          # 网站API服务
    ├── cmd/
    ├── internal/
    ├── pkg/
    ├── tests/
    ├── go.mod
    ├── go.sum
    └── Dockerfile
```

## ⚠️ 架构兼容性说明

**重要**: 由于本地开发环境可能使用ARM64架构（如M1/M2/M4 Mac），而腾讯云SCF运行环境为x86-64架构，所有Go应用必须进行交叉编译。

### 交叉编译参数
```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64
```

## 🔧 依赖管理

### 1. 初始化Go模块（如果需要）
```bash
cd backend/user-service
go mod init user-service
```

### 2. 下载依赖
```bash
# 进入每个服务目录
cd backend/user-service
go mod download
go mod tidy

cd ../notification-service
go mod download
go mod tidy

cd ../website-api
go mod download
go mod tidy
```

### 3. 验证依赖
```bash
go mod verify
go list -m all
```

## 🏗️ 编译构建

### 单个服务编译

#### User Service
```bash
cd backend/user-service

# 本地架构编译（开发调试用）
go build -o bin/user-service ./cmd/main.go

# 交叉编译（部署用）
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/user-service-linux ./cmd/main.go
```

#### Notification Service
```bash
cd backend/notification-service

# 本地架构编译
go build -o bin/notification-service ./cmd/main.go

# 交叉编译
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/notification-service-linux ./cmd/main.go
```

#### Website API
```bash
cd backend/website-api

# 本地架构编译
go build -o bin/website-api ./cmd/main.go

# 交叉编译
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/website-api-linux ./cmd/main.go
```

### 批量编译所有服务
```bash
# 使用自动化脚本
./scripts/03-build-and-package/build-backend.sh --all

# 或手动批量编译
for service in user-service notification-service website-api; do
    echo "编译 $service..."
    cd backend/$service
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/${service}-linux ./cmd/main.go
    cd ../..
done
```

## 🧪 单元测试

### 运行单个服务测试

#### User Service 测试
```bash
cd backend/user-service

# 运行所有测试
go test ./...

# 运行测试并显示覆盖率
go test -cover ./...

# 生成详细覆盖率报告
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

#### Notification Service 测试
```bash
cd backend/notification-service
go test ./...
go test -cover ./...
```

#### Website API 测试
```bash
cd backend/website-api
go test ./...
go test -cover ./...
```

### 批量运行所有测试
```bash
# 使用自动化脚本
./scripts/03-build-and-package/build-backend.sh --test-only

# 或手动批量测试
for service in user-service notification-service website-api; do
    echo "测试 $service..."
    cd backend/$service
    go test -v ./...
    cd ../..
done
```

### 基准测试
```bash
# 运行基准测试
go test -bench=. ./...

# 运行基准测试并生成性能分析
go test -bench=. -cpuprofile=cpu.prof -memprofile=mem.prof ./...
```

## 🔍 代码质量检查

### Go Vet 检查
```bash
# 检查单个服务
cd backend/user-service
go vet ./...

# 批量检查所有服务
for service in user-service notification-service website-api; do
    echo "检查 $service..."
    cd backend/$service
    go vet ./...
    cd ../..
done
```

### Go Fmt 格式化
```bash
# 格式化代码
go fmt ./...

# 检查格式化
gofmt -l .
```

### 静态分析（如果安装了golangci-lint）
```bash
# 安装 golangci-lint
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# 运行静态分析
golangci-lint run
```

## 📊 构建结果验证

### 1. 检查二进制文件
```bash
# 检查所有编译输出
find backend/ -name "bin" -type d -exec ls -la {} \;

# 验证架构兼容性
for service in user-service notification-service website-api; do
    if [ -f "backend/$service/bin/${service}-linux" ]; then
        echo "检查 $service 架构:"
        file "backend/$service/bin/${service}-linux"
    fi
done
```

### 2. 验证二进制文件可执行性
```bash
# 测试本地二进制文件
cd backend/user-service
./bin/user-service --version 2>/dev/null || echo "需要在Linux环境中运行"
```

### 3. 检查文件大小
```bash
# 查看二进制文件大小
find backend/ -name "*-linux" -exec ls -lh {} \;
```

## 🚀 自动化脚本

使用项目提供的自动化脚本：

```bash
# 完整的后端构建和测试流程
./scripts/03-build-and-package/build-backend.sh

# 仅编译所有服务
./scripts/03-build-and-package/build-backend.sh --build-only

# 仅运行测试
./scripts/03-build-and-package/build-backend.sh --test-only

# 编译特定服务
./scripts/03-build-and-package/build-backend.sh --service=user-service

# 清理构建输出
./scripts/03-build-and-package/build-backend.sh --clean
```

## 📈 性能优化

### 编译优化
```bash
# 优化编译，减小二进制文件大小
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bin/service-linux ./cmd/main.go

# 启用编译缓存
export GOCACHE=/tmp/go-cache
```

### 并行编译
```bash
# 设置并行编译数量
export GOMAXPROCS=4
```

## 🐛 常见问题

### 依赖下载问题
```bash
# 设置Go代理
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=sum.golang.google.cn

# 清理模块缓存
go clean -modcache
```

### 交叉编译问题
```bash
# 确保设置正确的环境变量
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64

# 验证目标架构
go env GOOS GOARCH
```

### 测试失败
```bash
# 运行详细测试
go test -v -race ./...

# 清理测试缓存
go clean -testcache
```

## ✅ 验证清单

- [ ] 所有服务依赖下载成功
- [ ] 本地架构编译成功
- [ ] 交叉编译成功（Linux x86-64）
- [ ] 所有单元测试通过
- [ ] 代码质量检查通过
- [ ] 二进制文件架构正确
- [ ] 性能基准测试完成

## 📝 下一步

后端编译和测试完成后，继续进行 [本地联合调试](./03-local-integration-debug.md)。