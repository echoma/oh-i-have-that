# 2️⃣ 后端编译及单元测试

## 📋 概述

本文档介绍如何编译后端Go服务并执行单元测试。项目包含多个微服务，需要进行交叉编译以确保在腾讯云SCF环境中正确运行。

## 🛠️ 前置条件

### 环境要求
- Go >= 1.19
- Git
- 完成环境设置（参考 [环境设置文档](../01-environment-setup/README.md)）

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
│   └── [类似结构]
└── website-api/          # 网站API服务
    └── [类似结构]
```

## ⚠️ 架构兼容性说明

**重要**: 由于本地开发环境可能使用ARM64架构（如M1/M2/M4 Mac），而腾讯云SCF运行环境为x86-64架构，所有Go应用必须进行交叉编译。

交叉编译参数：`CGO_ENABLED=0 GOOS=linux GOARCH=amd64`

## 🚀 使用自动化脚本

项目提供了完善的后端构建脚本，位于 `scripts/03-build-and-package/build-backend.sh`。

### 基本用法

```bash
# 完整的后端构建和测试流程（所有服务）
./scripts/03-build-and-package/build-backend.sh

# 构建特定服务
./scripts/03-build-and-package/build-backend.sh website-api
./scripts/03-build-and-package/build-backend.sh user-service notification-service

# 清理后构建
./scripts/03-build-and-package/build-backend.sh --clean --all

# 仅运行测试
./scripts/03-build-and-package/build-backend.sh --test

# 本地架构构建（用于本地测试）
./scripts/03-build-and-package/build-backend.sh --local

# 查看所有可用选项
./scripts/03-build-and-package/build-backend.sh --help
```

### 脚本功能特性

- ✅ **自动依赖管理**: 检查并下载Go模块依赖
- ✅ **交叉编译**: 自动进行Linux x86-64架构编译
- ✅ **多服务支持**: 支持单个或批量构建服务
- ✅ **架构验证**: 验证编译输出的目标架构
- ✅ **测试集成**: 可选运行单元测试和基准测试
- ✅ **构建分析**: 提供详细的构建结果和文件大小信息

### 可用服务

- `website-api` - 网站API服务
- `user-service` - 用户服务  
- `notification-service` - 通知服务

## 🔧 手动操作（可选）

如果需要手动执行特定步骤：

### 1. 依赖管理
```bash
# 进入服务目录
cd backend/user-service

# 下载依赖
go mod download
go mod tidy
go mod verify
```

### 2. 代码质量检查
```bash
# Go代码检查
go vet ./...

# 代码格式化
go fmt ./...

# 静态分析（如果安装了golangci-lint）
golangci-lint run
```

### 3. 单元测试
```bash
# 运行测试
go test ./...

# 带覆盖率的测试
go test -cover ./...

# 生成覆盖率报告
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### 4. 编译构建
```bash
# 本地架构编译（开发调试用）
go build -o bin/user-service ./cmd/main.go

# 交叉编译（部署用）
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/user-service ./cmd/main.go
```

## 📊 构建结果验证

### 检查构建输出
```bash
# 查看所有编译输出
find backend/ -name "bin" -type d -exec ls -la {} \;

# 检查文件大小
find backend/ -name "bin/*" -exec ls -lh {} \;
```

### 架构验证
```bash
# 验证目标架构（需要file命令）
for service in user-service notification-service website-api; do
    if [ -f "backend/$service/bin/$service" ]; then
        echo "检查 $service 架构:"
        file "backend/$service/bin/$service"
    fi
done
```

### 构建性能指标

自动化脚本会提供以下信息：
- 📊 各服务二进制文件大小
- 🏗️ 目标架构验证结果
- ⏱️ 构建耗时
- 🧪 测试结果（如果启用）

## 🐛 常见问题

### 依赖下载问题
```bash
# 设置Go代理（中国用户）
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=sum.golang.google.cn

# 清理模块缓存
go clean -modcache
```

### 交叉编译问题
```bash
# 确保环境变量设置正确
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

### 内存不足
```bash
# 设置并行编译数量
export GOMAXPROCS=2

# 或使用脚本的本地构建模式
./scripts/03-build-and-package/build-backend.sh --local
```

## ✅ 验证清单

- [ ] Go环境配置正确
- [ ] 所有服务依赖下载成功
- [ ] 代码质量检查通过
- [ ] 单元测试全部通过
- [ ] 本地架构编译成功
- [ ] 交叉编译成功（Linux x86-64）
- [ ] 二进制文件架构验证通过
- [ ] 构建输出大小合理

## 📝 下一步

后端编译和测试完成后，继续进行 [本地联合调试](./03-local-integration-debug.md)。

## 🔗 相关文档

- [环境设置](../01-environment-setup/README.md)
- [后端构建脚本源码](../../scripts/03-build-and-package/build-backend.sh)
- [故障排除指南](./troubleshooting.md)