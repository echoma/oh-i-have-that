# 📋 Oh I Have That 完整操作指南

---

# 第一部分：项目架构了解

## 🛠️ 技术栈

### 前端技术
- **HTML/CSS/JavaScript**: 基础前端技术
- **构建工具**: Node.js + npm
- **部署方式**: 静态文件托管

### 后端技术
- **Go语言**: 主要后端开发语言
- **微服务架构**: 多个独立的后端服务
- **容器化**: Docker镜像打包

### 基础设施
- **Terraform**: 基础设施即代码
- **Shell脚本**: 自动化部署脚本

## ☁️ 腾讯云产品

| 产品 | 用途 | 说明 |
|------|------|------|
| **COS对象存储** | 前端托管 | 静态网站托管，文件存储 |
| **SCF云函数** | 后端服务 | 无服务器计算，运行Go应用 |
| **CLB负载均衡** | 流量分发 | 公网流量接入，负载均衡 |
| **VPC私有网络** | 网络隔离 | 安全的网络环境 |
| **TCR容器镜像** | 镜像存储 | Docker镜像仓库 |
| **CLS日志服务** | 日志管理 | 应用日志收集和分析 |

## 🏗️ 系统架构

```
用户请求 → CLB负载均衡器 → SCF云函数 → 后端服务
                          ↓
                    处理API请求和静态文件
                          ↓
                    返回响应给用户
```

**流量分发规则：**
- `/api/*` → SCF处理动态API请求
- `/` 和其他路径 → SCF处理静态文件

## 📁 代码目录结构

```
oh-i-have-that/
├── backend/                    # 后端服务
│   ├── website-api/           # 网站API服务
│   ├── user-service/          # 用户管理服务
│   └── notification-service/  # 通知服务
├── frontend/                  # 前端应用
│   ├── src/                   # 源代码
│   ├── dist/                  # 构建输出
│   └── package.json           # 依赖配置
├── infrastructure/            # 基础设施代码
│   ├── modules/               # Terraform模块
│   ├── environments/          # 环境配置
│   └── main.tf               # 主配置文件
├── scripts/                   # 自动化脚本
│   ├── 01-environment-setup/  # 环境搭建脚本
│   ├── 02-infrastructure-setup/ # 基础设施部署脚本
│   ├── 03-build-and-package/  # 构建打包脚本
│   ├── 04-test-deployment/    # 测试环境部署脚本
│   └── 05-production-deployment/ # 生产环境部署脚本
├── docs/                      # 文档
│   ├── 01-environment-setup/  # 环境搭建文档
│   ├── 02-infrastructure-setup/ # 基础设施文档
│   ├── 03-build-and-package/  # 构建文档
│   ├── 04-test-deployment/    # 测试部署文档
│   └── 05-production-deployment/ # 生产部署文档
└── static-website/            # 静态网站文件
    └── dist/                  # 静态文件输出
```

---

# 第二部分：开发部署流程

## 🚀 操作流程概览

完整的开发部署流程分为5个步骤：

1. **环境搭建** → 配置开发环境和工具
2. **基础设施搭建** → 部署云资源
3. **编译构建** → 构建应用和镜像
4. **测试环境部署** → 部署到测试环境
5. **生产环境部署** → 部署到生产环境

## 📋 详细操作步骤

### 第一步：环境搭建
**目标**: 配置本地开发环境和必要工具

**操作**: 参考 [docs/01-environment-setup/README.md](docs/01-environment-setup/README.md)

**完成标志**: 
- 所有必要工具安装完成
- 腾讯云认证配置成功
- 环境变量设置正确

---

### 第二步：基础设施搭建
**目标**: 使用Terraform在腾讯云创建基础设施

**操作**: 参考 [docs/02-infrastructure-setup/README.md](docs/02-infrastructure-setup/README.md)

**完成标志**:
- 测试和生产环境基础设施部署成功
- VPC、COS、容器注册表等资源创建完成
- 如需动态后端功能，SCF和CLB配置完成

---

### 第三步：编译及镜像制作
**目标**: 编译前端应用、后端服务并制作Docker镜像

**操作**: 参考 [docs/03-build-and-package/README.md](docs/03-build-and-package/README.md)

**完成标志**:
- 前端构建完成，生成dist目录
- 后端服务编译完成，生成可执行文件
- Docker镜像构建完成并推送到仓库

---

### 第四步：测试环境部署
**目标**: 将应用部署到测试环境并进行验证

**操作**: 参考 [docs/04-test-deployment/README.md](docs/04-test-deployment/README.md)

**完成标志**:
- 前端部署到COS静态网站托管
- 后端服务部署到云函数
- 所有API端点正常响应
- 端到端测试通过

---

### 第五步：生产环境部署
**目标**: 将应用部署到生产环境，配置监控和安全策略

**操作**: 参考 [docs/05-production-deployment/README.md](docs/05-production-deployment/README.md)

**完成标志**:
- 生产环境基础设施部署完成
- 应用成功部署到生产环境
- 域名和SSL证书配置完成
- 监控和日志系统正常运行

## ✅ 完成检查清单

### 环境搭建 ✓
- [ ] 开发工具安装完成
- [ ] 腾讯云认证配置成功
- [ ] 环境变量设置正确

### 基础设施搭建 ✓
- [ ] 测试环境基础设施部署成功
- [ ] 生产环境基础设施部署成功
- [ ] 所有云资源创建完成

### 编译构建 ✓
- [ ] 前端应用构建成功
- [ ] 后端服务编译成功
- [ ] Docker镜像制作完成

### 测试环境部署 ✓
- [ ] 前端部署到测试环境
- [ ] 后端部署到测试环境
- [ ] 测试验证通过

### 生产环境部署 ✓
- [ ] 生产环境部署成功
- [ ] 域名和SSL配置完成
- [ ] 监控系统正常运行