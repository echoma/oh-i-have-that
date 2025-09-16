# 1️⃣ 前端编译及单元测试

## 📋 概述

本文档介绍如何编译前端应用并执行单元测试。前端项目使用现代JavaScript/TypeScript技术栈，支持开发和生产环境的不同构建配置。

## 🛠️ 前置条件

### 环境要求
- Node.js >= 16.0.0
- npm >= 8.0.0
- 完成环境设置（参考 [环境设置文档](../01-environment-setup/README.md)）

### 验证环境
```bash
node --version
npm --version
```

## 📁 项目结构

```
frontend/
├── src/                    # 源代码目录
│   ├── assets/            # 静态资源
│   ├── components/        # 组件
│   ├── pages/            # 页面
│   ├── utils/            # 工具函数
│   └── main.js           # 入口文件
├── tests/                 # 测试文件
├── dist/                  # 构建输出目录
├── package.json          # 项目配置
└── README.md             # 项目说明
```

## 🚀 使用自动化脚本

项目提供了完善的前端构建脚本，位于 `scripts/03-build-and-package/build-frontend.sh`。

### 基本用法

```bash
# 完整的前端构建和测试流程（生产模式）
./scripts/03-build-and-package/build-frontend.sh

# 开发模式构建
./scripts/03-build-and-package/build-frontend.sh --dev

# 清理后构建
./scripts/03-build-and-package/build-frontend.sh --clean --prod

# 构建并启动预览服务器
./scripts/03-build-and-package/build-frontend.sh --serve

# 查看所有可用选项
./scripts/03-build-and-package/build-frontend.sh --help
```

### 脚本功能特性

- ✅ **自动依赖管理**: 检查并安装必要的依赖
- ✅ **多种构建模式**: 支持开发和生产环境构建
- ✅ **代码质量检查**: 集成 ESLint 和格式化检查
- ✅ **构建优化**: 自动进行代码分割和资源压缩
- ✅ **构建分析**: 提供详细的构建结果分析
- ✅ **预览服务**: 构建后可选启动预览服务器

## 🔧 手动操作（可选）

如果需要手动执行特定步骤：

### 1. 依赖安装
```bash
cd frontend
npm install
```

### 2. 代码质量检查
```bash
npm run lint
npm run format  # 如果配置了格式化
```

### 3. 单元测试
```bash
npm test
npm run test:coverage  # 生成覆盖率报告
```

### 4. 构建应用
```bash
# 开发环境构建
npm run build:dev

# 生产环境构建
npm run build:prod
```

## 📊 构建结果验证

### 检查构建输出
```bash
# 查看构建目录
ls -la frontend/dist/

# 检查文件大小
du -sh frontend/dist/
```

预期输出结构：
```
frontend/dist/
├── assets/
│   ├── css/
│   ├── js/
│   └── images/
├── index.html
└── [其他静态文件]
```

### 构建性能指标

自动化脚本会提供以下信息：
- 📊 总构建大小
- 📋 主要文件列表和大小
- 📈 文件统计（HTML、CSS、JS文件数量）
- ⏱️ 构建耗时

## 🐛 常见问题

### 依赖安装问题
```bash
# 清理缓存和重新安装
npm cache clean --force
rm -rf frontend/node_modules frontend/package-lock.json
cd frontend && npm install
```

### 构建内存不足
```bash
# 增加 Node.js 内存限制
export NODE_OPTIONS="--max-old-space-size=4096"
./scripts/03-build-and-package/build-frontend.sh --prod
```

### 端口冲突
如果预览服务器端口被占用：
```bash
# 查找占用端口的进程
lsof -i :3000
# 杀死进程或使用不同端口
```

## ✅ 验证清单

- [ ] Node.js 和 npm 环境正常
- [ ] 依赖安装成功
- [ ] 代码质量检查通过
- [ ] 单元测试全部通过
- [ ] 开发环境构建成功
- [ ] 生产环境构建成功
- [ ] 构建输出文件完整
- [ ] 构建大小合理

## 📝 下一步

前端编译和测试完成后，继续进行 [后端编译及单元测试](./02-backend-build-test.md)。

## 🔗 相关文档

- [环境设置](../01-environment-setup/README.md)
- [前端构建脚本源码](../../scripts/03-build-and-package/build-frontend.sh)
- [故障排除指南](./troubleshooting.md)