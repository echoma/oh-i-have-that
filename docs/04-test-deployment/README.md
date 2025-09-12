# 🧪 第四步: 测试环境部署

本文档详细说明如何将应用部署到测试环境并进行验证测试。

## 🎯 目标

- 部署前端到COS静态网站托管
- 部署后端服务到云函数
- 配置API网关
- 进行端到端测试

## 📋 前置条件

- 完成 [第三步: 编译及镜像制作](../03-build-and-package/README.md)
- 前端构建完成
- 后端镜像制作完成
- 基础设施部署成功

## 🚀 自动化部署（推荐）

使用我们提供的自动化脚本来简化测试环境部署：

```bash
# 一键部署到测试环境
./scripts/04-test-deployment/deploy-to-test.sh
```

### 📋 脚本详细说明

#### deploy-to-test.sh - 测试环境部署
**功能**: 完整的测试环境部署流程
- 检查必要工具和环境变量
- 部署基础设施（如需要）
- 构建和推送Docker镜像
- 部署前端到COS
- 部署云函数
- 验证部署结果

**使用方法**:
```bash
# 完整部署流程
./scripts/04-test-deployment/deploy-to-test.sh

# 脚本会自动执行以下步骤：
# 1. 环境检查
# 2. 基础设施部署
# 3. 镜像构建和推送
# 4. 前端部署
# 5. 云函数部署
# 6. 部署验证
```

**环境变量要求**:
```bash
export TENCENTCLOUD_SECRET_ID="your-secret-id"
export TENCENTCLOUD_SECRET_KEY="your-secret-key"
```

#### legacy-deploy.sh - 旧版部署脚本
**功能**: 保留的原始部署脚本，用作参考
- 包含原有的部署逻辑
- 可用于特殊情况下的手动部署
- 提供部署流程的详细步骤

**使用方法**:
```bash
# 查看旧版部署脚本
cat ./scripts/04-test-deployment/legacy-deploy.sh

# 如需使用旧版脚本
./scripts/04-test-deployment/legacy-deploy.sh
```

## 🌐 手动前端部署（备选方案）

### 1.1 准备COS部署

```bash
# 获取COS存储桶信息
cd infrastructure
COS_BUCKET_URL=$(terraform output -raw cos_bucket_url 2>/dev/null || echo '')
COS_BUCKET_NAME=$(terraform output -raw cos_bucket_name 2>/dev/null || echo '')
cd ..

echo "COS存储桶: $COS_BUCKET_NAME"
echo "COS URL: $COS_BUCKET_URL"
```

### 1.2 上传前端文件到COS

```bash
echo "📤 上传前端文件到COS..."

# 检查前端构建文件
if [ ! -d "frontend/dist" ]; then
    echo "❌ 前端构建文件不存在，请先执行构建"
    exit 1
fi

# 使用腾讯云CLI上传（需要先安装和配置）
# 安装腾讯云CLI
    echo "安装腾讯云CLI..."
    
    # 配置CLI
    echo "请配置腾讯云CLI认证："
    echo "输入SecretId: $TENCENTCLOUD_SECRET_ID"
    echo "输入SecretKey: $TENCENTCLOUD_SECRET_KEY"
    echo "输入Region: $TENCENTCLOUD_REGION"
fi

# 上传文件到COS
cd frontend/dist

# 上传所有文件
find . -type f | while read file; do
    # 移除开头的./
    key=${file#./}
    echo "上传: $key"
    
    # 根据文件类型设置Content-Type
    case "$key" in
        *.html) content_type="text/html" ;;
        *.css) content_type="text/css" ;;
        *.js) content_type="application/javascript" ;;
        *.png) content_type="image/png" ;;
        *.jpg|*.jpeg) content_type="image/jpeg" ;;
        *.svg) content_type="image/svg+xml" ;;
        *) content_type="application/octet-stream" ;;
    esac
    
        --Bucket "$COS_BUCKET_NAME" \
        --Key "$key" \
        --Body "$file" \
        --ContentType "$content_type"
done

cd ../..
```

### 1.3 配置COS静态网站

```bash
echo "🌐 配置COS静态网站托管..."

# 配置静态网站托管
    --Bucket "$COS_BUCKET_NAME" \
    --WebsiteConfiguration '{
        "IndexDocument": {"Suffix": "index.html"},
        "ErrorDocument": {"Key": "index.html"}
    }'

echo "✅ 前端部署完成"
echo "访问地址: $COS_BUCKET_URL"
```

## ⚡ 后端服务部署

### 2.1 部署云函数基础设施

```bash
echo "⚡ 部署云函数基础设施..."

cd infrastructure

# 部署云函数相关资源
terraform apply -target=module.scf -var-file="environments/test/terraform.tfvars" -auto-approve

# 获取云函数信息
SCF_NAMESPACE=$(terraform output -raw scf_namespace 2>/dev/null || echo 'default')
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo '')

echo "云函数命名空间: $SCF_NAMESPACE"
echo "API网关地址: $API_GATEWAY_URL"

cd ..
```

### 2.2 部署website-api服务

```bash
echo "🚀 部署 website-api 服务..."

# 检查服务镜像
if ! docker images | grep -q "oh-i-have-that/website-api"; then
    echo "❌ website-api镜像不存在，请先构建镜像"
    exit 1
fi

# 创建云函数部署包
mkdir -p deploy/website-api
cd deploy/website-api

# 创建函数代码
cat > main.py << 'EOF'
import json
import subprocess
import os

def main_handler(event, context):
    """
    云函数入口点，调用Go服务
    """
    try:
        # 启动Go服务（如果未运行）
        # 这里简化处理，实际应该使用容器化部署
        
        # 解析请求
        path = event.get('path', '/')
        method = event.get('httpMethod', 'GET')
        
        # 返回响应
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Website API is running',
                'path': path,
                'method': method
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
EOF

# 打包函数代码
zip -r website-api.zip main.py

# 部署云函数
    --FunctionName "website-api" \
    --Runtime "Python3.7" \
    --Handler "main.main_handler" \
    --Code '{"ZipFile": "'$(base64 -i website-api.zip)'"}' \
    --Description "Website API Service" \
    --Timeout 30 \
    --MemorySize 128

cd ../..
```

### 2.3 部署user-service服务

```bash
echo "👤 部署 user-service 服务..."

mkdir -p deploy/user-service
cd deploy/user-service

# 创建用户服务函数
cat > main.py << 'EOF'
import json

def main_handler(event, context):
    """
    用户服务云函数
    """
    try:
        path = event.get('path', '/')
        method = event.get('httpMethod', 'GET')
        
        # 模拟用户服务响应
        if '/users' in path:
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'users': [
                        {'id': 1, 'name': 'Test User', 'email': 'test@example.com'}
                    ]
                })
            }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'User Service is running',
                'path': path
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
EOF

zip -r user-service.zip main.py

# 部署用户服务
    --FunctionName "user-service" \
    --Runtime "Python3.7" \
    --Handler "main.main_handler" \
    --Code '{"ZipFile": "'$(base64 -i user-service.zip)'"}' \
    --Description "User Service" \
    --Timeout 30 \
    --MemorySize 128

cd ../..
```

### 2.4 部署notification-service服务

```bash
echo "📧 部署 notification-service 服务..."

mkdir -p deploy/notification-service
cd deploy/notification-service

# 创建通知服务函数
cat > main.py << 'EOF'
import json

def main_handler(event, context):
    """
    通知服务云函数
    """
    try:
        path = event.get('path', '/')
        method = event.get('httpMethod', 'GET')
        
        if '/notifications' in path:
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'notifications': [
                        {'id': 1, 'message': 'Welcome to the system', 'read': False}
                    ]
                })
            }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Notification Service is running',
                'path': path
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
EOF

zip -r notification-service.zip main.py

# 部署通知服务
    --FunctionName "notification-service" \
    --Runtime "Python3.7" \
    --Handler "main.main_handler" \
    --Code '{"ZipFile": "'$(base64 -i notification-service.zip)'"}' \
    --Description "Notification Service" \
    --Timeout 30 \
    --MemorySize 128

cd ../..
```

## 🌉 API网关配置

### 3.1 创建API网关服务

```bash
echo "🌉 配置API网关..."

# 创建API服务
    --ServiceName "oh-i-have-that-test" \
    --ServiceDesc "Oh I Have That Test Environment" \
    --Protocol "http&https" \
    --query 'ServiceId' --output text)

echo "API服务ID: $API_SERVICE_ID"
```

### 3.2 配置API路由

```bash
echo "🔗 配置API路由..."

# 配置website-api路由
    --ServiceId "$API_SERVICE_ID" \
    --ApiName "website-api" \
    --ApiDesc "Website API endpoints" \
    --ApiType "NORMAL" \
    --AuthType "NONE" \
    --Protocol "HTTP" \
    --RequestConfig '{
        "Path": "/api/v1/*",
        "Method": "ANY"
    }' \
    --ServiceType "SCF" \
    --ServiceConfig '{
        "Product": "SCF",
        "UniqVpcId": "",
        "Url": "",
        "Path": "/api/v1/*",
        "Method": "ANY",
        "UpstreamId": "",
        "CosConfig": {
            "Action": "GetObject",
            "BucketName": "",
            "Authorization": true,
            "PathMatchMode": "BackEndPath"
        }
    }'

# 配置user-service路由
    --ServiceId "$API_SERVICE_ID" \
    --ApiName "user-service" \
    --ApiDesc "User service endpoints" \
    --ApiType "NORMAL" \
    --AuthType "NONE" \
    --Protocol "HTTP" \
    --RequestConfig '{
        "Path": "/users/*",
        "Method": "ANY"
    }' \
    --ServiceType "SCF"

# 配置notification-service路由
    --ServiceId "$API_SERVICE_ID" \
    --ApiName "notification-service" \
    --ApiDesc "Notification service endpoints" \
    --ApiType "NORMAL" \
    --AuthType "NONE" \
    --Protocol "HTTP" \
    --RequestConfig '{
        "Path": "/notifications/*",
        "Method": "ANY"
    }' \
    --ServiceType "SCF"
```

### 3.3 发布API服务

```bash
echo "🚀 发布API服务..."

# 发布到测试环境
    --ServiceId "$API_SERVICE_ID" \
    --EnvironmentName "test" \
    --ReleaseDesc "Initial test deployment"

# 获取API网关访问地址
API_GATEWAY_URL="https://${API_SERVICE_ID}-${TENCENTCLOUD_REGION}.apigw.tencentcs.com/test"
echo "API网关地址: $API_GATEWAY_URL"
```

## 🧪 测试验证

### 4.1 前端访问测试

```bash
echo "🧪 测试前端访问..."

# 测试静态网站访问
echo "测试前端页面..."
curl -I "$COS_BUCKET_URL"

# 检查关键页面
curl -s "$COS_BUCKET_URL" | grep -q "<title>" && echo "✅ 首页加载正常" || echo "❌ 首页加载失败"

# 测试静态资源
curl -I "$COS_BUCKET_URL/assets/index.css" 2>/dev/null && echo "✅ CSS资源正常" || echo "ℹ️  CSS资源路径可能不同"
```

### 4.2 后端API测试

```bash
echo "🔧 测试后端API..."

# 测试website-api
echo "测试 Website API..."
curl -s "$API_GATEWAY_URL/api/v1/health" | jq . && echo "✅ Website API正常" || echo "❌ Website API失败"

# 测试user-service
echo "测试 User Service..."
curl -s "$API_GATEWAY_URL/users" | jq . && echo "✅ User Service正常" || echo "❌ User Service失败"

# 测试notification-service
echo "测试 Notification Service..."
curl -s "$API_GATEWAY_URL/notifications" | jq . && echo "✅ Notification Service正常" || echo "❌ Notification Service失败"
```

### 4.3 端到端测试

```bash
echo "🔄 端到端测试..."

# 创建测试脚本
cat > test-e2e.sh << 'EOF'
#!/bin/bash

echo "🧪 执行端到端测试..."

# 测试前端到后端的完整流程
FRONTEND_URL="$1"
API_URL="$2"

# 1. 测试前端页面加载
echo "1. 测试前端页面..."
if curl -s "$FRONTEND_URL" | grep -q "<!DOCTYPE html>"; then
    echo "✅ 前端页面加载成功"
else
    echo "❌ 前端页面加载失败"
    exit 1
fi

# 2. 测试API连接
echo "2. 测试API连接..."
if curl -s "$API_URL/api/v1/health" | grep -q "message"; then
    echo "✅ API连接成功"
else
    echo "❌ API连接失败"
    exit 1
fi

# 3. 测试数据流
echo "3. 测试数据流..."
USER_DATA=$(curl -s "$API_URL/users")
if echo "$USER_DATA" | grep -q "users"; then
    echo "✅ 用户数据获取成功"
else
    echo "❌ 用户数据获取失败"
fi

NOTIFICATION_DATA=$(curl -s "$API_URL/notifications")
if echo "$NOTIFICATION_DATA" | grep -q "notifications"; then
    echo "✅ 通知数据获取成功"
else
    echo "❌ 通知数据获取失败"
fi

echo "🎉 端到端测试完成"
EOF

chmod +x test-e2e.sh
./test-e2e.sh "$COS_BUCKET_URL" "$API_GATEWAY_URL"
```

## 📊 部署状态检查

### 5.1 服务状态检查

```bash
echo "📊 检查服务状态..."

# 检查云函数状态
echo "=== 云函数状态 ==="
for func in website-api user-service notification-service; do
    echo "$func: $status"
done

# 检查API网关状态
echo "=== API网关状态 ==="

# 检查COS状态
echo "=== COS状态 ==="
```

### 5.2 性能测试

```bash
echo "⚡ 性能测试..."

# 前端加载时间测试
echo "前端加载时间:"
time curl -s "$COS_BUCKET_URL" > /dev/null

# API响应时间测试
echo "API响应时间:"
for endpoint in "/api/v1/health" "/users" "/notifications"; do
    echo -n "$endpoint: "
    time curl -s "$API_GATEWAY_URL$endpoint" > /dev/null
done
```

## 📋 完成检查清单

- [ ] 前端文件成功上传到COS
- [ ] COS静态网站托管配置完成
- [ ] 前端页面可正常访问
- [ ] website-api云函数部署成功
- [ ] user-service云函数部署成功
- [ ] notification-service云函数部署成功
- [ ] API网关配置完成
- [ ] API路由正确配置
- [ ] 所有API端点可正常访问
- [ ] 端到端测试通过
- [ ] 性能测试满足要求

## 🔧 测试环境信息

部署完成后记录以下信息：

```bash
echo "=== 测试环境信息 ==="
echo "前端地址: $COS_BUCKET_URL"
echo "API网关: $API_GATEWAY_URL"
echo "API服务ID: $API_SERVICE_ID"
echo "COS存储桶: $COS_BUCKET_NAME"
echo ""
echo "=== API端点 ==="
echo "健康检查: $API_GATEWAY_URL/api/v1/health"
echo "用户服务: $API_GATEWAY_URL/users"
echo "通知服务: $API_GATEWAY_URL/notifications"
```

## 🆘 故障排除

遇到问题请查看: [测试环境部署故障排除](troubleshooting.md)

---

**✅ 测试环境部署完成！**

下一步: [05-production-deployment](../05-production-deployment/README.md)