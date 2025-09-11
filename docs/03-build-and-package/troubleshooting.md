# 🆘 编译及镜像制作故障排除

## 前端构建问题

### 问题: npm构建失败

```bash
# 错误信息
npm ERR! Build failed with errors
```

**解决方案**:

```bash
# 1. 清理缓存和依赖
rm -rf node_modules package-lock.json
npm cache clean --force

# 2. 重新安装依赖
npm install

# 3. 检查Node.js版本
node --version
npm --version

# 4. 使用yarn替代npm
npm install -g yarn
yarn install
yarn build
```

### 问题: 前端资源路径错误

```bash
# 错误信息
Asset not found or path incorrect
```

**解决方案**:

```bash
# 1. 检查构建配置
cat frontend/package.json

# 2. 修复资源路径
# 在构建配置中设置正确的publicPath

# 3. 验证构建输出
ls -la frontend/dist/
find frontend/dist/ -name "*.html" -exec grep -l "assets" {} \;
```

## Go编译问题

### 问题: Go模块依赖错误

```bash
# 错误信息
go: module not found
```

**解决方案**:

```bash
# 1. 清理模块缓存
go clean -modcache

# 2. 重新下载依赖
cd backend/website-api
go mod tidy
go mod download

# 3. 验证模块
go mod verify
go list -m all

# 4. 如果仍然失败，设置代理
export GOPROXY=https://goproxy.cn,direct
go mod download
```

### 问题: 交叉编译失败

```bash
# 错误信息
unsupported GOOS/GOARCH pair
```

**解决方案**:

```bash
# 1. 检查目标平台
go env GOOS GOARCH

# 2. 设置正确的编译目标
export GOOS=linux
export GOARCH=amd64
go build -o service main.go

# 3. 或在构建命令中指定
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o service main.go
```

### 问题: CGO相关错误

```bash
# 错误信息
cgo: C compiler not found
```

**解决方案**:

```bash
# 1. 禁用CGO
export CGO_ENABLED=0
go build -o service main.go

# 2. 或安装C编译器
# Ubuntu/Debian
sudo apt-get install build-essential

# macOS
xcode-select --install

# 3. 验证编译环境
go env CGO_ENABLED
```

## Docker构建问题

### 问题: Docker构建失败

```bash
# 错误信息
ERROR: failed to solve: process "/bin/sh -c go build" did not complete successfully
```

**解决方案**:

```bash
# 1. 检查Dockerfile语法
docker build --no-cache -t test-image .

# 2. 分步构建调试
docker build --target builder -t debug-image .
docker run -it debug-image /bin/sh

# 3. 检查基础镜像
docker pull golang:1.21-alpine
docker run -it golang:1.21-alpine go version

# 4. 修复Dockerfile
cat > Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o service main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/service .
EXPOSE 8080
CMD ["./service"]
EOF
```

### 问题: Docker镜像过大

```bash
# 问题: 镜像大小超过预期
```

**解决方案**:

```bash
# 1. 使用多阶段构建
# 2. 使用更小的基础镜像
# 3. 清理不必要的文件

cat > Dockerfile << 'EOF'
# 构建阶段
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o service main.go

# 运行阶段
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/service /service
EXPOSE 8080
CMD ["/service"]
EOF

# 4. 检查镜像层
docker history your-image:latest

# 5. 使用.dockerignore
cat > .dockerignore << 'EOF'
.git
.gitignore
README.md
Dockerfile
.dockerignore
node_modules
npm-debug.log
EOF
```

### 问题: Docker网络问题

```bash
# 错误信息
dial tcp: lookup proxy.golang.org: no such host
```

**解决方案**:

```bash
# 1. 在Dockerfile中设置代理
ENV GOPROXY=https://goproxy.cn,direct
ENV GOSUMDB=sum.golang.google.cn

# 2. 或在构建时传递参数
docker build --build-arg GOPROXY=https://goproxy.cn,direct .

# 3. 检查Docker网络
docker network ls
docker run --rm alpine ping google.com
```

## 容器注册表问题

### 问题: Docker登录失败

```bash
# 错误信息
Error response from daemon: unauthorized
```

**解决方案**:

```bash
# 1. 检查登录凭据
docker login --username=your-username your-registry.com

# 2. 获取正确的登录命令
echo "请从腾讯云控制台获取登录命令"
echo "控制台地址: https://console.cloud.tencent.com/tcr"

# 3. 验证登录状态
docker info | grep -A 10 "Registry Mirrors"

# 4. 手动配置认证
mkdir -p ~/.docker
cat > ~/.docker/config.json << 'EOF'
{
    "auths": {
        "your-registry.com": {
            "auth": "base64-encoded-credentials"
        }
    }
}
EOF
```

### 问题: 镜像推送失败

```bash
# 错误信息
denied: requested access to the resource is denied
```

**解决方案**:

```bash
# 1. 检查镜像标签
docker images | grep your-image

# 2. 正确标记镜像
docker tag local-image:tag registry-url/namespace/image:tag

# 3. 检查推送权限
echo "确保有推送权限到目标仓库"

# 4. 重新推送
docker push registry-url/namespace/image:tag
```

## 构建性能问题

### 问题: 构建速度慢

**解决方案**:

```bash
# 1. 使用构建缓存
docker build --cache-from your-image:latest .

# 2. 并行构建
make -j$(nproc) build-all

# 3. 优化Dockerfile层
# 将不经常变化的操作放在前面
# 合并RUN命令减少层数

# 4. 使用.dockerignore
echo "node_modules" >> .dockerignore
echo ".git" >> .dockerignore

# 5. Go构建优化
go build -ldflags="-s -w" -o service main.go
```

### 问题: 磁盘空间不足

```bash
# 错误信息
no space left on device
```

**解决方案**:

```bash
# 1. 清理Docker缓存
docker system prune -a -f

# 2. 清理构建缓存
docker builder prune -a -f

# 3. 删除未使用的镜像
docker image prune -a -f

# 4. 检查磁盘使用
df -h
du -sh ~/.docker

# 5. 清理Go缓存
go clean -cache
go clean -modcache
```

## 依赖管理问题

### 问题: 版本冲突

```bash
# 错误信息
version conflict
```

**解决方案**:

```bash
# 1. 检查依赖版本
go list -m all
npm list

# 2. 更新依赖
go get -u ./...
npm update

# 3. 锁定版本
# 在go.mod中指定具体版本
# 在package.json中使用确切版本号

# 4. 清理并重新安装
go mod tidy
rm -rf node_modules && npm install
```

## 完整构建脚本

创建自动化构建脚本 `build-all.sh`:

```bash
#!/bin/bash

set -e

echo "🔨 开始完整构建流程..."

# 1. 构建前端
echo "📦 构建前端应用..."
cd frontend
npm install
npm run build
cd ..

# 2. 编译后端
echo "⚙️ 编译后端服务..."
services=("website-api" "user-service" "notification-service")

for service in "${services[@]}"; do
    echo "编译 $service..."
    cd "backend/$service"
    go mod tidy
    go build -ldflags="-s -w" -o "$service" main.go
    cd "../.."
done

# 3. 构建Docker镜像
echo "🐳 构建Docker镜像..."
for service in "${services[@]}"; do
    echo "构建 $service 镜像..."
    cd "backend/$service"
    docker build -t "oh-i-have-that/$service:latest" .
    cd "../.."
done

# 4. 验证构建结果
echo "✅ 验证构建结果..."
echo "前端构建大小: $(du -sh frontend/dist | cut -f1)"
echo "Docker镜像:"
docker images | grep oh-i-have-that

echo "🎉 构建完成！"
```

使用脚本:

```bash
chmod +x build-all.sh
./build-all.sh
```

---

如果以上解决方案都无法解决问题，请：

1. 查看详细的构建日志
2. 检查系统资源使用情况
3. 验证所有依赖版本兼容性
4. 在项目Issues中搜索类似问题