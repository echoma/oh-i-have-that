# 📦 第一步: 开发环境搭建

本文档说明如何搭建Oh I Have That项目的开发环境。

## 🎯 目标

- 安装所有必需的开发工具
- 配置腾讯云认证
- 下载项目依赖
- 验证开发环境

## 🚀 自动化安装

使用提供的脚本来简化环境搭建：

```bash
# 一键设置开发环境
./scripts/01-environment-setup/setup-dev-env.sh

# 下载Go依赖
./scripts/01-environment-setup/download-deps.sh

# 安装前端依赖
./scripts/01-environment-setup/install-frontend-deps.sh
```

详细的脚本使用方法请参考 `scripts/01-environment-setup/` 目录中的脚本文件。

## 🔑 腾讯云认证配置（必须手工执行）

### 获取腾讯云访问密钥

1. 登录腾讯云控制台
2. 访问 [API密钥管理](https://console.cloud.tencent.com/cam/capi)
3. 创建新的API密钥
4. 记录 `SecretId` 和 `SecretKey`

### 配置认证信息

```bash
# 设置环境变量（推荐）
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

## 📋 完成检查清单

- [ ] 开发工具安装完成（运行 `./scripts/01-environment-setup/setup-dev-env.sh`）
- [ ] 腾讯云认证配置完成
- [ ] 项目依赖下载完成（运行 `./scripts/01-environment-setup/download-deps.sh`）
- [ ] 前端依赖安装完成（运行 `./scripts/01-environment-setup/install-frontend-deps.sh`）

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