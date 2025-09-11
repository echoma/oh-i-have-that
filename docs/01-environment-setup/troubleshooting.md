# 🆘 开发环境搭建故障排除

## Go依赖问题 {#go-dependencies}

### 问题: Go模块下载失败

```bash
# 错误信息
go: module github.com/gin-gonic/gin: Get "https://proxy.golang.org/...": dial tcp: i/o timeout
```

**解决方案**:

```bash
# 1. 设置Go代理为国内镜像
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=sum.golang.google.cn

# 2. 清理模块缓存
go clean -modcache

# 3. 重新下载依赖
cd backend/website-api
go mod download
go mod tidy

# 4. 验证下载
go mod verify
```

### 问题: checksum mismatch

```bash
# 错误信息
verifying module: checksum mismatch
```

**解决方案**:

```bash
# 删除go.sum文件并重新生成
rm go.sum
go mod tidy
go mod download
```

## Node.js问题 {#nodejs-issues}

### 问题: npm install失败

```bash
# 错误信息
npm ERR! network timeout
```

**解决方案**:

```bash
# 1. 设置npm镜像源
npm config set registry https://registry.npmmirror.com

# 2. 清理缓存
npm cache clean --force

# 3. 删除node_modules重新安装
rm -rf node_modules package-lock.json
npm install

# 4. 如果仍然失败，使用yarn
npm install -g yarn
yarn install
```

### 问题: 权限错误

```bash
# 错误信息
EACCES: permission denied
```

**解决方案**:

```bash
# macOS/Linux: 修复npm权限
sudo chown -R $(whoami) ~/.npm
sudo chown -R $(whoami) /usr/local/lib/node_modules

# 或使用nvm管理Node.js版本
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install node
nvm use node
```

## Docker问题 {#docker-issues}

### 问题: Docker服务未启动

```bash
# 错误信息
Cannot connect to the Docker daemon
```

**解决方案**:

```bash
# macOS: 启动Docker Desktop
open /Applications/Docker.app

# Linux: 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证Docker状态
docker info
```

### 问题: Docker权限问题

```bash
# 错误信息
permission denied while trying to connect to the Docker daemon socket
```

**解决方案**:

```bash
# Linux: 将用户添加到docker组
sudo usermod -aG docker $USER
newgrp docker

# 验证权限
docker run hello-world
```

## 腾讯云认证问题 {#auth-issues}

### 问题: 认证失败

```bash
# 错误信息
[TencentCloudSDKException] Code=AuthFailure.SignatureFailure
```

**解决方案**:

```bash
# 1. 检查密钥是否正确
echo "SecretId: $TENCENTCLOUD_SECRET_ID"
echo "SecretKey: ${TENCENTCLOUD_SECRET_KEY:0:10}..."

# 2. 重新设置环境变量
export TENCENTCLOUD_SECRET_ID="your-correct-secret-id"
export TENCENTCLOUD_SECRET_KEY="your-correct-secret-key"
export TENCENTCLOUD_REGION="ap-guangzhou"

# 3. 测试认证
terraform plan -var-file="infrastructure/environments/test/terraform.tfvars"
```

### 问题: 地域不支持

```bash
# 错误信息
The region is not supported
```

**解决方案**:

```bash
# 使用支持的地域
export TENCENTCLOUD_REGION="ap-guangzhou"  # 广州
# 或
export TENCENTCLOUD_REGION="ap-shanghai"   # 上海
export TENCENTCLOUD_REGION="ap-beijing"    # 北京
```

## Terraform问题

### 问题: Terraform初始化失败

```bash
# 错误信息
Error: Failed to install provider
```

**解决方案**:

```bash
# 1. 清理Terraform缓存
rm -rf .terraform .terraform.lock.hcl

# 2. 设置Terraform镜像源
export TF_REGISTRY_MIRROR=https://registry.terraform.io

# 3. 重新初始化
terraform init

# 4. 如果仍然失败，手动下载provider
terraform init -upgrade
```

## 网络连接问题

### 问题: 网络超时

**解决方案**:

```bash
# 1. 检查网络连接
ping google.com
ping cloud.tencent.com

# 2. 如果在企业网络，配置代理
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080

# 3. 测试代理连接
curl -I https://google.com
```

## 工具版本问题

### 问题: 工具版本过低

**解决方案**:

```bash
# 升级Go
# 访问 https://golang.org/dl/ 下载最新版本

# 升级Node.js
# 使用nvm管理版本
nvm install --lts
nvm use --lts

# 升级Terraform
# 访问 https://www.terraform.io/downloads.html

# 升级Docker
# 访问 https://docs.docker.com/get-docker/
```

## 环境变量问题

### 问题: 环境变量未生效

**解决方案**:

```bash
# 1. 检查当前shell
echo $SHELL

# 2. 根据shell类型编辑配置文件
# bash用户
vim ~/.bashrc
# zsh用户  
vim ~/.zshrc

# 3. 添加环境变量
export TENCENTCLOUD_SECRET_ID="your-secret-id"
export TENCENTCLOUD_SECRET_KEY="your-secret-key"
export TENCENTCLOUD_REGION="ap-guangzhou"

# 4. 重新加载配置
source ~/.bashrc  # 或 source ~/.zshrc

# 5. 验证环境变量
env | grep TENCENTCLOUD
```

## 完整环境检查脚本

创建检查脚本 `check-environment.sh`:

```bash
#!/bin/bash

echo "🔍 检查开发环境..."

# 检查Go
if command -v go &> /dev/null; then
    echo "✅ Go: $(go version)"
else
    echo "❌ Go未安装"
fi

# 检查Node.js
if command -v node &> /dev/null; then
    echo "✅ Node.js: $(node --version)"
else
    echo "❌ Node.js未安装"
fi

# 检查Terraform
if command -v terraform &> /dev/null; then
    echo "✅ Terraform: $(terraform version | head -1)"
else
    echo "❌ Terraform未安装"
fi

# 检查Docker
if command -v docker &> /dev/null; then
    echo "✅ Docker: $(docker --version)"
else
    echo "❌ Docker未安装"
fi

# 检查环境变量
if [ -n "$TENCENTCLOUD_SECRET_ID" ]; then
    echo "✅ 腾讯云认证已配置"
else
    echo "❌ 腾讯云认证未配置"
fi

echo "🔍 环境检查完成"
```

使用脚本:

```bash
chmod +x check-environment.sh
./check-environment.sh
```

---

如果以上解决方案都无法解决问题，请：

1. 检查系统日志获取更详细的错误信息
2. 查看官方文档获取最新解决方案
3. 在项目Issues中搜索类似问题
4. 提交新的Issue描述具体问题和环境信息