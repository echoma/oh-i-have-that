# 1️⃣ 前端编译及单元测试

## 📋 概述

本文档介绍如何编译前端应用并执行单元测试。前端项目使用现代JavaScript/TypeScript技术栈，支持开发和生产环境的不同构建配置。

## 🛠️ 前置条件

### 环境要求
- Node.js >= 16.0.0
- npm >= 8.0.0 或 yarn >= 1.22.0
- Git

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
├── build.js              # 构建脚本
└── README.md             # 项目说明
```

## 🔧 依赖安装

### 1. 进入前端目录
```bash
cd frontend
```

### 2. 安装依赖
```bash
# 使用 npm
npm install

# 或使用 yarn
yarn install
```

### 3. 验证依赖安装
```bash
npm list --depth=0
```

## 🏗️ 编译构建

### 开发环境构建
```bash
# 开发环境构建（包含调试信息）
npm run build:dev

# 或使用构建脚本
node build.js --env=development
```

### 生产环境构建
```bash
# 生产环境构建（优化压缩）
npm run build:prod

# 或使用构建脚本
node build.js --env=production
```

### 监听模式构建
```bash
# 文件变化时自动重新构建
npm run build:watch
```

## 🧪 单元测试

### 运行所有测试
```bash
# 运行单元测试
npm test

# 运行测试并生成覆盖率报告
npm run test:coverage
```

### 运行特定测试
```bash
# 运行特定测试文件
npm test -- --grep "组件名称"

# 运行特定目录的测试
npm test tests/components/
```

### 测试监听模式
```bash
# 监听模式运行测试
npm run test:watch
```

## 📊 构建结果验证

### 1. 检查构建输出
```bash
ls -la dist/
```

预期输出结构：
```
dist/
├── assets/
│   ├── css/
│   ├── js/
│   └── images/
├── index.html
└── build-info.json
```

### 2. 验证构建信息
```bash
cat dist/build-info.json
```

### 3. 检查文件大小
```bash
du -sh dist/
find dist/ -name "*.js" -exec ls -lh {} \;
```

## 🔍 代码质量检查

### ESLint 检查
```bash
npm run lint

# 自动修复可修复的问题
npm run lint:fix
```

### 代码格式化
```bash
npm run format
```

### 类型检查（如果使用TypeScript）
```bash
npm run type-check
```

## 🚀 自动化脚本

使用项目提供的自动化脚本：

```bash
# 完整的前端构建和测试流程
./scripts/03-build-and-package/build-frontend.sh

# 仅构建
./scripts/03-build-and-package/build-frontend.sh --build-only

# 仅测试
./scripts/03-build-and-package/build-frontend.sh --test-only

# 生产环境构建
./scripts/03-build-and-package/build-frontend.sh --prod
```

## 📈 性能优化

### 构建性能优化
- 启用并行构建
- 使用缓存机制
- 优化依赖解析

### 输出优化
- 代码分割
- 资源压缩
- Tree shaking

## 🐛 常见问题

### 依赖安装问题
```bash
# 清理缓存
npm cache clean --force

# 删除 node_modules 重新安装
rm -rf node_modules package-lock.json
npm install
```

### 构建内存不足
```bash
# 增加 Node.js 内存限制
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build:prod
```

### 测试失败
```bash
# 更新测试快照
npm test -- --updateSnapshot

# 清理测试缓存
npm test -- --clearCache
```

## ✅ 验证清单

- [ ] 依赖安装成功
- [ ] 开发环境构建成功
- [ ] 生产环境构建成功
- [ ] 所有单元测试通过
- [ ] 代码质量检查通过
- [ ] 构建输出文件完整
- [ ] 构建信息正确

## 📝 下一步

前端编译和测试完成后，继续进行 [后端编译及单元测试](./02-backend-build-test.md)。