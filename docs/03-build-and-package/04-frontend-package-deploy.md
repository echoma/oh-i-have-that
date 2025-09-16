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

## 🏗️ 生产环境构建

### 1. 环境配置

#### 生产环境变量配置
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
REACT_APP_VERSION=$npm_package_version
REACT_APP_BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
```

#### 构建配置优化
```javascript
// frontend/build.config.js
const buildConfig = {
  production: {
    // 代码分割
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
    minimizer: {
      terser: {
        terserOptions: {
          compress: {
            drop_console: true,
            drop_debugger: true,
          },
        },
      },
    },
    
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

### 2. 生产环境构建

#### 清理之前的构建
```bash
cd frontend

# 清理构建目录
rm -rf dist/
rm -rf build/

# 清理缓存
npm cache clean --force
```

#### 执行生产构建
```bash
# 设置生产环境
export NODE_ENV=production

# 执行构建
npm run build:prod

# 或使用构建脚本
node build.js --env=production --optimize
```

#### 验证构建输出
```bash
# 检查构建结果
ls -la dist/

# 检查文件大小
du -sh dist/
find dist/ -name "*.js" -exec ls -lh {} \;
find dist/ -name "*.css" -exec ls -lh {} \;

# 检查构建信息
cat dist/build-info.json
```

## 📦 资源优化

### 1. 静态资源压缩

#### Gzip压缩
```bash
# 生成gzip压缩文件
find dist/ -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \) -exec gzip -k {} \;

# 检查压缩效果
find dist/ -name "*.gz" -exec sh -c 'echo "原文件: $(stat -f%z "${1%%.gz}") bytes, 压缩后: $(stat -f%z "$1") bytes, 压缩率: $(echo "scale=2; $(stat -f%z "$1") * 100 / $(stat -f%z "${1%%.gz}")" | bc)%"' _ {} \;
```

#### Brotli压缩
```bash
# 安装brotli工具
npm install -g brotli

# 生成brotli压缩文件
find dist/ -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \) -exec brotli {} \;
```

### 2. 图片优化

#### 图片压缩
```bash
# 安装图片优化工具
npm install -g imagemin-cli

# 压缩图片
imagemin dist/assets/images/* --out-dir=dist/assets/images/optimized/

# 生成WebP格式
find dist/assets/images/ -name "*.jpg" -o -name "*.png" | xargs -I {} cwebp {} -o {}.webp
```

#### 响应式图片
```javascript
// 生成不同尺寸的图片
const sharp = require('sharp');

const generateResponsiveImages = async (inputPath, outputDir) => {
  const sizes = [320, 640, 960, 1280, 1920];
  
  for (const size of sizes) {
    await sharp(inputPath)
      .resize(size)
      .jpeg({ quality: 80 })
      .toFile(`${outputDir}/image-${size}w.jpg`);
  }
};
```

### 3. 代码优化

#### Tree Shaking验证
```bash
# 分析bundle大小
npm install -g webpack-bundle-analyzer

# 生成分析报告
npx webpack-bundle-analyzer dist/static/js/*.js
```

#### 未使用代码检测
```bash
# 安装未使用代码检测工具
npm install -g depcheck

# 检测未使用的依赖
depcheck

# 检测未使用的代码
npm install -g unimported
unimported
```

## 🌐 CDN部署准备

### 1. 静态资源CDN配置

#### 资源路径重写
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

// 使用示例
const imageUrl = getCDNUrl('/assets/images/logo.png');
```

#### 构建时资源路径处理
```javascript
// frontend/build.js 中添加CDN路径处理
const fs = require('fs');
const path = require('path');

const updateAssetPaths = (distDir, cdnBaseUrl) => {
  const htmlFile = path.join(distDir, 'index.html');
  let html = fs.readFileSync(htmlFile, 'utf8');
  
  // 替换静态资源路径
  html = html.replace(/\/assets\//g, `${cdnBaseUrl}/assets/`);
  
  fs.writeFileSync(htmlFile, html);
  console.log('CDN路径更新完成');
};

// 如果指定了CDN URL，则更新路径
if (process.env.CDN_BASE_URL) {
  updateAssetPaths('./dist', process.env.CDN_BASE_URL);
}
```

### 2. 缓存策略配置

#### 生成缓存清单
```javascript
// frontend/scripts/generate-cache-manifest.js
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const generateCacheManifest = (distDir) => {
  const manifest = {};
  
  const walkDir = (dir) => {
    const files = fs.readdirSync(dir);
    
    files.forEach(file => {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        walkDir(filePath);
      } else {
        const content = fs.readFileSync(filePath);
        const hash = crypto.createHash('md5').update(content).digest('hex');
        const relativePath = path.relative(distDir, filePath);
        
        manifest[relativePath] = {
          hash,
          size: stat.size,
          lastModified: stat.mtime.toISOString()
        };
      }
    });
  };
  
  walkDir(distDir);
  
  fs.writeFileSync(
    path.join(distDir, 'cache-manifest.json'),
    JSON.stringify(manifest, null, 2)
  );
  
  console.log('缓存清单生成完成');
};

generateCacheManifest('./dist');
```

## 🚀 部署准备

### 1. 腾讯云COS部署准备

#### 生成部署脚本
```bash
#!/bin/bash
# scripts/deploy/deploy-frontend-to-cos.sh

set -e

BUCKET_NAME="your-bucket-name"
REGION="ap-guangzhou"
LOCAL_PATH="./frontend/dist/"
COS_PATH="/"

echo "=== 前端部署到腾讯云COS ==="

# 1. 验证构建文件
if [ ! -d "$LOCAL_PATH" ]; then
    echo "错误: 构建目录不存在: $LOCAL_PATH"
    exit 1
fi

# 2. 同步文件到COS
echo "同步文件到COS..."
coscli sync "$LOCAL_PATH" "cos://$BUCKET_NAME$COS_PATH" \
    --include="*" \
    --delete \
    --meta="Cache-Control:max-age=31536000" \
    --meta-directive="REPLACE"

# 3. 设置HTML文件缓存策略
echo "设置HTML文件缓存策略..."
coscli cp "$LOCAL_PATH/index.html" "cos://$BUCKET_NAME/index.html" \
    --meta="Cache-Control:no-cache" \
    --meta-directive="REPLACE"

# 4. 设置CDN刷新
echo "刷新CDN缓存..."
# 这里可以调用腾讯云CDN API刷新缓存

echo "=== 前端部署完成 ==="
```

### 2. 部署验证脚本

```bash
#!/bin/bash
# scripts/deploy/verify-frontend-deployment.sh

DOMAIN="https://yourdomain.com"

echo "=== 验证前端部署 ==="

# 1. 检查主页
echo "检查主页..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DOMAIN")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 主页访问正常"
else
    echo "❌ 主页访问失败，HTTP状态码: $HTTP_CODE"
    exit 1
fi

# 2. 检查静态资源
echo "检查静态资源..."
ASSETS=$(curl -s "$DOMAIN" | grep -o 'assets/[^"]*' | head -5)
for asset in $ASSETS; do
    ASSET_URL="$DOMAIN/$asset"
    ASSET_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ASSET_URL")
    if [ "$ASSET_CODE" = "200" ]; then
        echo "✅ 资源正常: $asset"
    else
        echo "❌ 资源失败: $asset (HTTP: $ASSET_CODE)"
    fi
done

# 3. 检查API连接
echo "检查API连接..."
API_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DOMAIN/api/health")
if [ "$API_CODE" = "200" ]; then
    echo "✅ API连接正常"
else
    echo "⚠️  API连接异常，HTTP状态码: $API_CODE"
fi

echo "=== 部署验证完成 ==="
```

## 📊 性能监控

### 1. 构建性能分析

```javascript
// frontend/scripts/build-performance.js
const fs = require('fs');
const path = require('path');

const analyzeBuildPerformance = (distDir) => {
  const stats = {
    totalSize: 0,
    fileCount: 0,
    jsSize: 0,
    cssSize: 0,
    imageSize: 0,
    largestFiles: []
  };
  
  const walkDir = (dir) => {
    const files = fs.readdirSync(dir);
    
    files.forEach(file => {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        walkDir(filePath);
      } else {
        stats.totalSize += stat.size;
        stats.fileCount++;
        
        const ext = path.extname(file).toLowerCase();
        if (ext === '.js') stats.jsSize += stat.size;
        else if (ext === '.css') stats.cssSize += stat.size;
        else if (['.jpg', '.png', '.gif', '.webp'].includes(ext)) {
          stats.imageSize += stat.size;
        }
        
        stats.largestFiles.push({
          path: path.relative(distDir, filePath),
          size: stat.size
        });
      }
    });
  };
  
  walkDir(distDir);
  
  // 排序最大文件
  stats.largestFiles.sort((a, b) => b.size - a.size);
  stats.largestFiles = stats.largestFiles.slice(0, 10);
  
  // 输出分析结果
  console.log('=== 构建性能分析 ===');
  console.log(`总文件数: ${stats.fileCount}`);
  console.log(`总大小: ${(stats.totalSize / 1024 / 1024).toFixed(2)} MB`);
  console.log(`JS文件大小: ${(stats.jsSize / 1024).toFixed(2)} KB`);
  console.log(`CSS文件大小: ${(stats.cssSize / 1024).toFixed(2)} KB`);
  console.log(`图片文件大小: ${(stats.imageSize / 1024).toFixed(2)} KB`);
  
  console.log('\n最大的10个文件:');
  stats.largestFiles.forEach((file, index) => {
    console.log(`${index + 1}. ${file.path} - ${(file.size / 1024).toFixed(2)} KB`);
  });
  
  return stats;
};

analyzeBuildPerformance('./dist');
```

### 2. 运行时性能监控

```javascript
// frontend/src/utils/performance.js
export const performanceMonitor = {
  // 页面加载性能
  measurePageLoad() {
    window.addEventListener('load', () => {
      const perfData = performance.getEntriesByType('navigation')[0];
      
      console.log('页面性能指标:');
      console.log(`DNS查询: ${perfData.domainLookupEnd - perfData.domainLookupStart}ms`);
      console.log(`TCP连接: ${perfData.connectEnd - perfData.connectStart}ms`);
      console.log(`请求响应: ${perfData.responseEnd - perfData.requestStart}ms`);
      console.log(`DOM解析: ${perfData.domContentLoadedEventEnd - perfData.domLoading}ms`);
      console.log(`页面加载: ${perfData.loadEventEnd - perfData.navigationStart}ms`);
    });
  },
  
  // 资源加载性能
  measureResourceLoad() {
    const resources = performance.getEntriesByType('resource');
    
    resources.forEach(resource => {
      if (resource.duration > 1000) { // 超过1秒的资源
        console.warn(`慢资源: ${resource.name} - ${resource.duration.toFixed(2)}ms`);
      }
    });
  },
  
  // Core Web Vitals
  measureCoreWebVitals() {
    // LCP (Largest Contentful Paint)
    new PerformanceObserver((entryList) => {
      const entries = entryList.getEntries();
      const lastEntry = entries[entries.length - 1];
      console.log('LCP:', lastEntry.startTime);
    }).observe({ entryTypes: ['largest-contentful-paint'] });
    
    // FID (First Input Delay)
    new PerformanceObserver((entryList) => {
      const entries = entryList.getEntries();
      entries.forEach(entry => {
        console.log('FID:', entry.processingStart - entry.startTime);
      });
    }).observe({ entryTypes: ['first-input'] });
    
    // CLS (Cumulative Layout Shift)
    let clsValue = 0;
    new PerformanceObserver((entryList) => {
      const entries = entryList.getEntries();
      entries.forEach(entry => {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
        }
      });
      console.log('CLS:', clsValue);
    }).observe({ entryTypes: ['layout-shift'] });
  }
};

// 在应用启动时初始化性能监控
performanceMonitor.measurePageLoad();
performanceMonitor.measureCoreWebVitals();
```

## 🚀 自动化部署脚本

```bash
#!/bin/bash
# scripts/03-build-and-package/build-and-deploy-frontend.sh

set -e

echo "=== 前端打包发布自动化脚本 ==="

# 1. 环境检查
echo "1. 检查环境..."
cd frontend
npm --version || { echo "错误: npm未安装"; exit 1; }

# 2. 依赖检查
echo "2. 检查依赖..."
npm ci

# 3. 代码质量检查
echo "3. 代码质量检查..."
npm run lint
npm run type-check

# 4. 单元测试
echo "4. 运行单元测试..."
npm test -- --coverage --watchAll=false

# 5. 生产构建
echo "5. 生产环境构建..."
export NODE_ENV=production
npm run build:prod

# 6. 构建验证
echo "6. 构建验证..."
node scripts/build-performance.js

# 7. 资源优化
echo "7. 资源优化..."
find dist/ -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \) -exec gzip -k {} \;

# 8. 生成部署清单
echo "8. 生成部署清单..."
node scripts/generate-cache-manifest.js

# 9. 部署到COS（如果指定）
if [ "$DEPLOY_TO_COS" = "true" ]; then
    echo "9. 部署到腾讯云COS..."
    ./scripts/deploy/deploy-frontend-to-cos.sh
    
    echo "10. 验证部署..."
    ./scripts/deploy/verify-frontend-deployment.sh
fi

echo "=== 前端打包发布完成 ==="
```

## ✅ 验证清单

- [ ] 生产环境配置正确
- [ ] 构建优化配置完成
- [ ] 静态资源压缩完成
- [ ] 图片优化完成
- [ ] CDN配置准备完成
- [ ] 缓存策略配置完成
- [ ] 部署脚本准备完成
- [ ] 性能监控配置完成
- [ ] 构建性能分析完成

## 📝 下一步

前端打包发布完成后，继续进行 [后端打包发布](./05-backend-package-deploy.md)。