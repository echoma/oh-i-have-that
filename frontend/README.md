# 静态网站资源

这个目录包含Oh I Have That的所有静态资源，包括HTML、CSS、JavaScript和图片等。

## 📁 目录结构

```
frontend/
├── src/                    # 源代码目录
│   ├── index.html         # 首页
│   ├── error.html         # 错误页面
│   └── assets/            # 静态资源
│       ├── css/           # 样式文件
│       ├── js/            # JavaScript文件
│       └── images/        # 图片资源
├── dist/                  # 构建输出目录
├── build.js              # 构建脚本
├── package.json          # 项目配置
└── README.md            # 说明文档
```

## 🚀 快速开始

### 安装依赖

```bash
cd frontend
npm install
```

### 开发模式

```bash
# 构建并启动本地服务器
npm run dev

# 监听文件变化自动构建
npm run watch
```

### 生产构建

```bash
# 生产环境构建
npm run build:prod

# 构建完成后部署
npm run deploy
```

## 🛠️ 构建系统

### 构建脚本功能

- **HTML处理**: 变量替换、压缩
- **CSS处理**: 压缩、优化
- **JavaScript处理**: API URL替换、压缩
- **资源复制**: 图片等静态资源直接复制

### 环境变量

- `NODE_ENV`: 环境模式 (development/production)
- `API_BASE_URL`: API基础URL
- `VERSION`: 版本号

### 构建配置

创建 `build.config.json` 文件自定义构建配置：

```json
{
  "minify": true,
  "apiBaseUrl": "https://your-api-gateway-url",
  "version": "1.0.0"
}
```

## 📝 开发指南

### 添加新页面

1. 在 `src/` 目录创建新的HTML文件
2. 运行构建脚本处理文件
3. 更新导航和链接

### 修改样式

1. 编辑 `src/assets/css/style.css`
2. 使用CSS变量保持一致性
3. 遵循响应式设计原则

### 添加JavaScript功能

1. 编辑 `src/assets/js/main.js`
2. 使用ES6+语法
3. 确保与API的兼容性

### 添加图片资源

1. 将图片放入 `src/assets/images/`
2. 使用适当的格式和大小
3. 在HTML中使用相对路径引用

## 🎨 设计系统

### 颜色变量

```css
--primary-color: #667eea;
--secondary-color: #764ba2;
--accent-color: #f093fb;
--success-color: #4ecdc4;
--warning-color: #ffe066;
--error-color: #ff6b6b;
```

### 组件样式

- **按钮**: `.btn`, `.btn-primary`, `.btn-secondary`
- **卡片**: `.feature-card`
- **容器**: `.container`
- **网格**: `.features`

## 🔧 与Terraform集成

### 自动部署到COS

构建脚本与Terraform COS模块集成：

1. 运行 `npm run build:prod` 生成dist目录
2. Terraform读取dist目录内容
3. 自动上传到COS存储桶

### 更新COS模块

修改 `infrastructure/modules/cos/main.tf`：

```hcl
# 上传构建后的文件
resource "tencentcloud_cos_bucket_object" "website_files" {
  for_each = fileset("${path.module}/../../../frontend/dist", "**/*")
  
  bucket = tencentcloud_cos_bucket.website.bucket
  key    = each.value
  source = "${path.module}/../../../frontend/dist/${each.value}"
  acl    = "public-read"
  
  content_type = lookup({
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "gif"  = "image/gif"
    "svg"  = "image/svg+xml"
    "ico"  = "image/x-icon"
  }, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}
```

## 📱 响应式设计

网站支持多种设备：

- **桌面**: 1200px+
- **平板**: 768px - 1199px
- **手机**: < 768px

使用CSS Grid和Flexbox实现响应式布局。

## 🔍 SEO优化

- 语义化HTML标签
- 适当的meta标签
- 结构化数据
- 图片alt属性
- 页面标题和描述

## 🚀 性能优化

- CSS和JS压缩
- 图片优化
- 缓存策略
- CDN加速（通过COS）
- 懒加载

## 🧪 测试

### 本地测试

```bash
# 启动本地服务器
npm run serve

# 访问 http://localhost:8080
```

### 构建测试

```bash
# 测试生产构建
npm run build:prod
npm run serve
```

## 📦 部署流程

1. **开发**: 在src目录编写代码
2. **构建**: 运行构建脚本生成dist
3. **测试**: 本地验证构建结果
4. **部署**: Terraform自动上传到COS
5. **验证**: 访问COS网站URL确认

## 🤝 贡献指南

1. 遵循现有的代码风格
2. 确保响应式设计
3. 测试多种浏览器兼容性
4. 更新相关文档
5. 提交前运行构建测试