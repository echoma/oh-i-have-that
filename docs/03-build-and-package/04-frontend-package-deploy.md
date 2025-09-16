# 4️⃣ 前端打包发布

## 📋 概述

本文档介绍如何为生产环境打包前端应用，包括性能优化、静态资源处理、CDN部署准备等步骤。

## 🛠️ 前置条件

### 环境要求
- 完成前端编译和单元测试
- 完成本地联合调试
- Node.js >= 16.0.0
- 确保所有依赖已安装

### 验证前置条件
```bash
# 检查前端项目状态
cd frontend
npm list --depth=0

# 检查开发构建是否正常
ls -la dist/
```

## 🚀 使用自动化脚本

项目提供了完善的前端构建脚本，可以处理生产环境的所有优化需求。

### 生产环境构建

```bash
# 生产环境构建（包含所有优化）
./scripts/03-build-and-package/build-frontend.sh --prod

# 清理后生产构建
./scripts/03-build-and-package/build-frontend.sh --clean --prod

# 构建并分析包大小
./scripts/03-build-and-package/build-frontend.sh --analyze

# 构建后启动预览服务器
./scripts/03-build-and-package/build-frontend.sh --prod --serve

# 查看所有可用选项
./scripts/03-build-and-package/build-frontend.sh --help
```

### 脚本功能特性

- ✅ **生产优化**: 自动进行代码压缩、Tree shaking
- ✅ **资源优化**: 自动处理图片、CSS、JS文件优化
- ✅ **缓存策略**: 生成带hash的文件名用于缓存控制
- ✅ **构建分析**: 提供详细的构建结果和性能分析
- ✅ **预览服务**: 构建后可选启动预览服务器验证结果

## 🏗️ 生产环境配置

### 1. 环境变量配置

创建生产环境配置文件：

```bash
# 创建生产环境配置
cat > frontend/.env.production << EOF
# API配置
REACT_APP_API_BASE_URL=https://api.yourdomain.com
REACT_APP_USER_SERVICE_URL=https://api.yourdomain.com/user
REACT_APP_NOTIFICATION_SERVICE_URL=https://api.yourdomain.com/notification

# 功能开关
REACT_APP_ENABLE_ANALYTICS=true
REACT_APP_ENABLE_DEBUG=false

# CDN配置
REACT_APP_CDN_BASE_URL=https://cdn.yourdomain.com
REACT_APP_STATIC_ASSETS_URL=https://static.yourdomain.com

# 版本信息
REACT_APP_VERSION=\$npm_package_version
REACT_APP_BUILD_TIME=\$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
```

### 2. 构建配置优化

如果需要自定义构建配置，可以创建或修改构建配置文件：

```javascript
// frontend/build.config.js 或 webpack.config.js
const buildConfig = {
  production: {
    // 代码分割配置
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all',
        },
        common: {
          name: 'common',
          minChunks: 2,
          chunks: 'all',
        }
      }
    },
    
    // 压缩配置
    minimize: true,
    
    // 输出配置
    output: {
      filename: 'assets/js/[name].[contenthash:8].js',
      chunkFilename: 'assets/js/[name].[contenthash:8].chunk.js',
      assetModuleFilename: 'assets/media/[name].[hash:8][ext]',
    }
  }
};

module.exports = buildConfig;
```

## 📦 资源优化

### 1. 自动优化功能

构建脚本自动包含以下优化：

- **代码压缩**: JavaScript和CSS文件自动压缩
- **Tree Shaking**: 移除未使用的代码
- **资源压缩**: 图片和其他静态资源优化
- **缓存优化**: 文件名包含内容hash用于缓存控制

### 2. 手动优化（可选）

如果需要额外的优化：

```bash
# 生成gzip压缩文件
find frontend/dist/ -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \) -exec gzip -k {} \;

# 分析bundle大小（如果安装了分析工具）
npx webpack-bundle-analyzer frontend/dist/static/js/*.js

# 检测未使用的依赖
npx depcheck frontend/
```

## 🌐 CDN部署准备

### 1. 静态资源CDN配置

如果使用CDN，可以配置资源路径：

```javascript
// frontend/src/utils/cdn.js
const CDN_CONFIG = {
  production: {
    baseUrl: 'https://cdn.yourdomain.com',
    version: process.env.REACT_APP_VERSION,
  },
  development: {
    baseUrl: '',
    version: 'dev',
  }
};

export const getCDNUrl = (path) => {
  const config = CDN_CONFIG[process.env.NODE_ENV] || CDN_CONFIG.development;
  return `${config.baseUrl}/${config.version}${path}`;
};
```

### 2. 缓存策略

构建脚本会自动生成带hash的文件名，建议的缓存策略：

- **HTML文件**: `Cache-Control: no-cache`
- **JS/CSS文件**: `Cache-Control: max-age=31536000` (1年)
- **图片文件**: `Cache-Control: max-age=2592000` (30天)

## 🚀 部署准备

### 1. 腾讯云COS部署

如果部署到腾讯云COS，可以创建部署脚本：

```bash
#!/bin/bash
# scripts/deploy/deploy-frontend-to-cos.sh

set -e

BUCKET_NAME="your-bucket-name"
REGION="ap-guangzhou"
LOCAL_PATH="./frontend/dist/"
COS_PATH="/"

echo "=== 前端部署到腾讯云COS ==="

# 验证构建文件
if [ ! -d "$LOCAL_PATH" ]; then
    echo "错误: 构建目录不存在: $LOCAL_PATH"
    exit 1
fi

# 同步文件到COS
echo "同步文件到COS..."
coscli sync "$LOCAL_PATH" "cos://$BUCKET_NAME$COS_PATH" \
    --include="*" \
    --delete \
    --meta="Cache-Control:max-age=31536000" \
    --meta-directive="REPLACE"

# 设置HTML文件缓存策略
echo "设置HTML文件缓存策略..."
coscli cp "$LOCAL_PATH/index.html" "cos://$BUCKET_NAME/index.html" \
    --meta="Cache-Control:no-cache" \
    --meta-directive="REPLACE"

echo "=== 前端部署完成 ==="
```

### 2. 部署验证

创建部署验证脚本：

```bash
#!/bin/bash
# scripts/deploy/verify-frontend-deployment.sh

DOMAIN="https://yourdomain.com"

echo "=== 验证前端部署 ==="

# 检查主页
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DOMAIN")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 主页访问正常"
else
    echo "❌ 主页访问失败，HTTP状态码: $HTTP_CODE"
    exit 1
fi

# 检查静态资源
echo "检查静态资源..."
ASSETS=$(curl -s "$DOMAIN" | grep -o 'assets/[^"]*' | head -3)
for asset in $ASSETS; do
    ASSET_URL="$DOMAIN/$asset"
    ASSET_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ASSET_URL")
    if [ "$ASSET_CODE" = "200" ]; then
        echo "✅ 资源正常: $asset"
    else
        echo "❌ 资源失败: $asset (HTTP: $ASSET_CODE)"
    fi
done

echo "=== 部署验证完成 ==="
```

## 📊 性能监控

### 1. 构建性能分析

构建脚本会自动提供性能分析，包括：

- 📊 总文件大小和数量
- 📋 主要文件列表和大小
- 📈 不同类型文件的统计
- ⏱️ 构建耗时

### 2. 运行时性能监控

可以在应用中添加性能监控：

```javascript
// frontend/src/utils/performance.js
export const performanceMonitor = {
  // 页面加载性能
  measurePageLoad() {
    window.addEventListener('load', () => {
      const perfData = performance.getEntriesByType('navigation')[0];
      console.log('页面加载耗时:', perfData.loadEventEnd - perfData.navigationStart, 'ms');
    });
  },
  
  // 资源加载性能
  measureResourceLoad() {
    const resources = performance.getEntriesByType('resource');
    resources.forEach(resource => {
      if (resource.duration > 1000) {
        console.warn(`慢资源: ${resource.name} - ${resource.duration.toFixed(2)}ms`);
      }
    });
  }
};

// 在应用启动时初始化
performanceMonitor.measurePageLoad();
```

## 🚀 完整部署流程

### 自动化部署脚本

```bash
#!/bin/bash
# deploy-frontend.sh

set -e

echo "=== 前端完整部署流程 ==="

# 1. 生产环境构建
echo "1. 生产环境构建..."
./scripts/03-build-and-package/build-frontend.sh --clean --prod

# 2. 构建验证
echo "2. 构建验证..."
[ -d "frontend/dist" ] || { echo "构建失败"; exit 1; }
echo "构建大小: $(du -sh frontend/dist | cut -f1)"

# 3. 部署到COS（如果配置了）
if [ "$DEPLOY_TO_COS" = "true" ]; then
    echo "3. 部署到腾讯云COS..."
    ./scripts/deploy/deploy-frontend-to-cos.sh
    
    echo "4. 验证部署..."
    ./scripts/deploy/verify-frontend-deployment.sh
fi

echo "=== 前端部署完成 ==="
```

## 🐛 常见问题

### 构建失败
```bash
# 清理缓存和重新构建
rm -rf frontend/node_modules frontend/package-lock.json
cd frontend && npm install
./scripts/03-build-and-package/build-frontend.sh --clean --prod
```

### 构建过慢
```bash
# 增加Node.js内存限制
export NODE_OPTIONS="--max-old-space-size=4096"
./scripts/03-build-and-package/build-frontend.sh --prod
```

### 资源路径问题
```bash
# 检查构建输出的资源路径
grep -r "assets/" frontend/dist/index.html
```

## ✅ 验证清单

- [ ] 生产环境配置正确
- [ ] 构建脚本执行成功
- [ ] 构建输出文件完整
- [ ] 静态资源路径正确
- [ ] 文件大小合理
- [ ] 缓存策略配置正确
- [ ] 部署脚本准备完成
- [ ] 性能监控配置完成

## 📝 下一步

前端打包发布完成后，继续进行 [后端打包发布](./05-backend-package-deploy.md)。

## 🔗 相关文档

- [前端构建脚本源码](../../scripts/03-build-and-package/build-frontend.sh)
- [本地联合调试](./03-local-integration-debug.md)
- [故障排除指南](./troubleshooting.md)