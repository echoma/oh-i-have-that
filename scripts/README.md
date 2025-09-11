# 脚本目录说明

本目录包含项目各个阶段的自动化脚本，按照工作流程进行组织。

## 📖 使用说明

**重要提示**: 本目录中的脚本仅提供自动化执行功能。关于每个脚本的详细使用方法、参数说明、功能介绍等，请查看 `docs/` 文件夹中对应步骤的文档：

- 📋 **脚本使用指南**: 请前往 [docs/STEP_BY_STEP.md](../docs/STEP_BY_STEP.md) 查看完整的操作流程
- 🔧 **详细使用方法**: 每个脚本的具体使用方法请查看对应的docs子目录：
  - `docs/01-environment-setup/README.md` - 环境搭建脚本使用说明
  - `docs/02-infrastructure-setup/README.md` - 基础设施脚本使用说明
  - `docs/03-build-and-package/README.md` - 构建打包脚本使用说明
  - `docs/04-test-deployment/README.md` - 测试部署脚本使用说明
  - `docs/05-production-deployment/README.md` - 生产部署脚本使用说明

## 📁 目录结构

```
scripts/
├── 01-environment-setup/     # 开发环境搭建
├── 02-infrastructure-setup/  # 基础设施部署
├── 03-build-and-package/     # 构建和打包
├── 04-test-deployment/       # 测试环境部署
├── 05-production-deployment/  # 生产环境部署
└── README.md                 # 本文件
```

## 🚀 快速开始

### 1. 开发环境搭建
```bash
# 设置开发环境
./scripts/01-environment-setup/setup-dev-env.sh

# 下载Go依赖
./scripts/01-environment-setup/download-deps.sh

# 安装前端依赖
./scripts/01-environment-setup/install-frontend-deps.sh
```

### 2. 基础设施部署
```bash
# 初始化Terraform状态存储
./scripts/02-infrastructure-setup/init-state-storage.sh

# 管理Terraform工作空间
./scripts/02-infrastructure-setup/workspace.sh

# 部署基础设施
./scripts/02-infrastructure-setup/deploy-infrastructure.sh
```

### 3. 构建和打包
```bash
# 构建前端
./scripts/03-build-and-package/build-frontend.sh

# 构建后端
./scripts/03-build-and-package/build-backend.sh

# 构建Docker镜像
./scripts/03-build-and-package/build-docker-images.sh
```

### 4. 测试环境部署
```bash
# 部署到测试环境
./scripts/04-test-deployment/deploy-to-test.sh

# 查看旧版部署脚本（参考）
./scripts/04-test-deployment/legacy-deploy.sh
```

### 5. 生产环境部署
```bash
# 部署到生产环境（需要特殊确认）
./scripts/05-production-deployment/deploy-to-prod.sh
```

## 📋 脚本说明

### 01-environment-setup/
- **setup-dev-env.sh**: 一键设置开发环境，安装必要工具
- **download-deps.sh**: 下载Go模块依赖，配置代理
- **install-frontend-deps.sh**: 安装前端npm依赖

### 02-infrastructure-setup/
- **init-state-storage.sh**: 初始化Terraform远程状态存储
- **workspace.sh**: 创建和管理Terraform工作空间
- **deploy-infrastructure.sh**: 部署腾讯云基础设施

### 03-build-and-package/
- **build-frontend.sh**: 构建前端静态资源
- **build-backend.sh**: 编译Go后端应用
- **build-docker-images.sh**: 构建和推送Docker镜像

### 04-test-deployment/
- **deploy-to-test.sh**: 完整的测试环境部署流程
- **legacy-deploy.sh**: 原有的部署脚本（保留作参考）

### 05-production-deployment/
- **deploy-to-prod.sh**: 生产环境部署，包含安全检查和蓝绿部署

## ⚠️ 注意事项

1. **权限要求**: 所有脚本都需要可执行权限
2. **环境变量**: 部署脚本需要设置腾讯云认证信息
3. **依赖关系**: 按照编号顺序执行，后续步骤依赖前面的结果
4. **生产部署**: 生产环境部署需要特殊确认，请谨慎操作

## 🔧 环境变量

部署相关脚本需要以下环境变量：

```bash
export TENCENTCLOUD_SECRET_ID="your-secret-id"
export TENCENTCLOUD_SECRET_KEY="your-secret-key"
```

## 📖 更多信息

详细的操作指南请参考 [docs/STEP_BY_STEP.md](../docs/STEP_BY_STEP.md)。