# 📦 第一步: 开发环境搭建

本文档详细说明如何搭建Oh I Have That项目的完整开发环境。

## 🎯 目标

- 安装所有必需的开发工具
- 配置腾讯云认证
- 下载项目依赖
- 验证开发环境

## 📋 环境要求检查

### 必需工具安装

```bash
# 1. 检查Go版本 (需要1.21+)
go version
# 如果未安装: https://golang.org/dl/

# 2. 检查Node.js版本 (需要16+)
node --version
npm --version
# 如果未安装: https://nodejs.org/

# 3. 检查Terraform版本 (需要1.0+)
terraform version
# 如果未安装: https://www.terraform.io/downloads.html

# 4. 检查Docker版本 (需要20+)
docker --version
# 如果未安装: https://docs.docker.com/get-docker/

# 5. 检查Make工具
make --version
# macOS: xcode-select --install
# Ubuntu: sudo apt-get install build-essential
```

## 🔑 腾讯云认证配置

### 1.1 获取腾讯云访问密钥

1. 登录腾讯云控制台
2. 访问 [API密钥管理](https://console.cloud.tencent.com/cam/capi)
3. 创建新的API密钥
4. 记录 `SecretId` 和 `SecretKey`

### 1.2 配置认证信息

```bash
# 方法1: 设置环境变量（推荐）
export TENCENTCLOUD_SECRET_ID="your-secret-id"
export TENCENTCLOUD_SECRET_KEY="your-secret-key"
export TENCENTCLOUD_REGION="ap-guangzhou"

# 验证认证配置
echo $TENCENTCLOUD_SECRET_ID

# 永久设置 (添加到 ~/.bashrc 或 ~/.zshrc)
echo 'export TENCENTCLOUD_SECRET_ID="your-secret-id"' >> ~/.bashrc
echo 'export TENCENTCLOUD_SECRET_KEY="your-secret-key"' >> ~/.bashrc
echo 'export TENCENTCLOUD_REGION="ap-guangzhou"' >> ~/.bashrc
source ~/.bashrc
```

## 📥 项目初始化

### 2.1 克隆项目

```bash
git clone <your-repository-url>
cd oh-i-have-that

# 查看项目结构
ls -la
```

### 2.2 下载项目依赖

```bash
# 下载Go模块依赖
make download-deps

# 如果make命令失败，手动执行：
cd backend/website-api && go mod download && cd ../..
cd backend/user-service && go mod download && cd ../..
cd backend/notification-service && go mod download && cd ../..

# 安装前端依赖
cd frontend
npm install
cd ..

# 检查依赖状态
make status
```

## ✅ 环境验证

### 3.1 验证Go环境

```bash
# 测试Go编译
cd backend/website-api
go build -o test-build main.go
ls -la test-build
rm test-build
cd ../..
```

### 3.2 验证Node.js环境

```bash
# 测试前端构建
cd frontend
npm run build
ls -la dist/
cd ..
```

### 3.3 验证Docker环境

```bash
# 测试Docker构建
docker --version
docker info
```

### 3.4 验证Terraform环境

```bash
# 测试Terraform
cd infrastructure
terraform version
terraform validate
cd ..
```

## 🔧 本地开发环境

### 4.1 启动前端开发服务器

```bash
cd frontend
npm run dev
# 访问 http://localhost:3000
```

### 4.2 启动后端开发服务器

```bash
# 新终端窗口
cd backend/website-api
go run main.go
# 访问 http://localhost:8080
```

### 4.3 测试本地服务

```bash
# 测试前端
curl http://localhost:3000

# 测试后端API
curl http://localhost:8080/api/v1/health
curl http://localhost:8080/api/v1/user/test-user

# 测试API认证
curl -X POST http://localhost:8080/api/v1/auth/check \
  -H "Content-Type: application/json" \
  -d '{"token":"test-token","userId":"test-user"}'
```

## 📋 完成检查清单

- [ ] Go 1.21+ 已安装并可正常使用
- [ ] Node.js 16+ 已安装并可正常使用  
- [ ] Terraform 1.0+ 已安装并可正常使用
- [ ] Docker 20+ 已安装并可正常使用
- [ ] Make工具已安装
- [ ] 腾讯云认证配置完成
- [ ] 项目依赖下载完成
- [ ] 本地开发服务器可正常启动
- [ ] API接口测试通过

## 🆘 故障排除

### 常见问题

1. **Go依赖下载失败**
   - 参考: [Go依赖问题解决](troubleshooting.md#go-dependencies)

2. **Node.js依赖安装失败**
   - 参考: [Node.js问题解决](troubleshooting.md#nodejs-issues)

3. **Docker服务未启动**
   - 参考: [Docker问题解决](troubleshooting.md#docker-issues)

4. **腾讯云认证失败**
   - 参考: [认证问题解决](troubleshooting.md#auth-issues)

---

**✅ 环境搭建完成！** 

下一步: [02-infrastructure-setup](../02-infrastructure-setup/README.md)