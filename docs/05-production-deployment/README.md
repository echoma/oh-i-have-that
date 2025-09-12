# 🚀 第五步: 生产环境部署

本文档详细说明如何将应用部署到生产环境，包括安全配置、性能优化和监控设置。

## 🎯 目标

- 部署生产级基础设施
- 配置安全策略和访问控制
- 部署应用到生产环境
- 设置监控和日志
- 配置域名和SSL证书

## 📋 前置条件

- 完成 [第四步: 测试环境部署](../04-test-deployment/README.md)
- 测试环境验证通过
- 生产环境规划完成
- 域名和SSL证书准备就绪

## 🚀 自动化生产部署（推荐）

使用我们提供的自动化脚本来简化生产环境部署：

```bash
# 一键部署到生产环境
./scripts/05-production-deployment/deploy-to-prod.sh
```

### 📋 脚本详细说明

#### deploy-to-prod.sh - 生产环境部署
**功能**: 完整的生产环境部署流程
- 生产环境安全检查
- 部署基础设施到生产环境
- 构建和推送生产镜像
- 部署前端到生产COS
- 部署云函数到生产环境
- 配置生产域名和SSL
- 执行生产验证测试

**使用方法**:
```bash
# 完整生产部署流程
./scripts/05-production-deployment/deploy-to-prod.sh

# 脚本会自动执行以下步骤：
# 1. 生产环境安全检查
# 2. 基础设施部署
# 3. 生产镜像构建
# 4. 前端生产部署
# 5. 云函数生产部署
# 6. 域名和SSL配置
# 7. 生产验证测试
```

**环境变量要求**:
```bash
export TENCENTCLOUD_SECRET_ID="your-secret-id"
export TENCENTCLOUD_SECRET_KEY="your-secret-key"
export PROD_DOMAIN="your-production-domain.com"  # 可选
```

**安全注意事项**:
- 脚本会进行多重确认
- 自动备份现有配置
- 支持回滚操作
- 包含安全检查清单

## 🏗️ 手动生产基础设施部署（备选方案）

### 1.1 切换到生产环境

```bash
echo "🏗️ 切换到生产环境..."

cd infrastructure

# 切换到生产工作空间
terraform workspace select prod || terraform workspace new prod

# 验证当前环境
echo "当前环境: $(terraform workspace show)"

# 检查生产环境配置
if [ ! -f "environments/prod/terraform.tfvars" ]; then
    echo "创建生产环境配置..."
    cp environments/test/terraform.tfvars environments/prod/terraform.tfvars
    
    # 修改生产环境特定配置
    sed -i 's/test/prod/g' environments/prod/terraform.tfvars
    sed -i 's/project_name = "oh-i-have-that"/project_name = "oh-i-have-that-prod"/' environments/prod/terraform.tfvars
fi

cd ..
```

### 1.2 部署生产基础设施

```bash
echo "🚀 部署生产基础设施..."

cd infrastructure

# 初始化生产环境
terraform init

# 查看部署计划
terraform plan -var-file="environments/prod/terraform.tfvars"

# 部署基础设施
echo "部署网络基础设施..."
terraform apply -target=module.network -var-file="environments/prod/terraform.tfvars" -auto-approve

echo "部署存储基础设施..."
terraform apply -target=module.cos -var-file="environments/prod/terraform.tfvars" -auto-approve

echo "部署容器注册表..."
terraform apply -target=module.container_registry -var-file="environments/prod/terraform.tfvars" -auto-approve

echo "部署云函数基础设施..."
terraform apply -target=module.scf -var-file="environments/prod/terraform.tfvars" -auto-approve

# 获取生产环境信息
PROD_COS_BUCKET_URL=$(terraform output -raw cos_bucket_url)
PROD_COS_BUCKET_NAME=$(terraform output -raw cos_bucket_name)
PROD_CONTAINER_REGISTRY_URL=$(terraform output -raw container_registry_url 2>/dev/null || echo '')

echo "=== 生产环境信息 ==="
echo "COS存储桶: $PROD_COS_BUCKET_NAME"
echo "COS URL: $PROD_COS_BUCKET_URL"
echo "容器注册表: $PROD_CONTAINER_REGISTRY_URL"

cd ..
```

### 1.3 配置生产安全策略

```bash
echo "🔒 配置生产安全策略..."

cd infrastructure

# 配置COS存储桶安全策略
    --Bucket "$PROD_COS_BUCKET_NAME" \
    --Policy '{
        "version": "2.0",
        "statement": [
            {
                "principal": {"qcs": ["qcs::cam::anyone:anyone"]},
                "effect": "allow",
                "action": ["cos:GetObject"],
                "resource": ["qcs::cos:'$TENCENTCLOUD_REGION':'$PROD_COS_BUCKET_NAME'/*"],
                "condition": {
                    "string_equal": {
                        "cos:x-cos-referer": ["https://yourdomain.com", "https://www.yourdomain.com"]
                    }
                }
            }
        ]
    }'

# 配置HTTPS重定向
    --Bucket "$PROD_COS_BUCKET_NAME" \
    --WebsiteConfiguration '{
        "IndexDocument": {"Suffix": "index.html"},
        "ErrorDocument": {"Key": "index.html"},
        "RedirectAllRequestsTo": {"Protocol": "https"}
    }'

cd ..
```

## 🎨 生产前端部署

### 2.1 构建生产前端

```bash
echo "🎨 构建生产前端..."

cd frontend

# 设置生产环境变量
export NODE_ENV=production
export VITE_API_URL="https://your-api-domain.com"
export VITE_APP_VERSION="1.0.0"

# 清理之前的构建
rm -rf dist/

# 安装依赖并构建
npm ci --production=false
npm run build

# 验证构建结果
echo "构建文件大小:"
du -sh dist/
echo "构建文件列表:"
find dist/ -type f | head -10

cd ..
```

### 2.2 优化前端资源

```bash
echo "⚡ 优化前端资源..."

cd frontend/dist

# 压缩HTML文件
find . -name "*.html" -exec gzip -k {} \;

# 压缩CSS文件
find . -name "*.css" -exec gzip -k {} \;

# 压缩JS文件
find . -name "*.js" -exec gzip -k {} \;

# 设置缓存策略
create_upload_script() {
    cat > upload_optimized.sh << 'EOF'
#!/bin/bash

upload_file() {
    local file="$1"
    local key="${file#./}"
    local content_type="$2"
    local cache_control="$3"
    
    # 上传原文件
        --Bucket "$PROD_COS_BUCKET_NAME" \
        --Key "$key" \
        --Body "$file" \
        --ContentType "$content_type" \
        --CacheControl "$cache_control"
    
    # 如果存在gzip版本，也上传
    if [ -f "$file.gz" ]; then
            --Bucket "$PROD_COS_BUCKET_NAME" \
            --Key "$key" \
            --Body "$file.gz" \
            --ContentType "$content_type" \
            --ContentEncoding "gzip" \
            --CacheControl "$cache_control"
    fi
}

# 上传HTML文件（短缓存）
find . -name "*.html" | while read file; do
    upload_file "$file" "text/html" "max-age=300"
done

# 上传CSS/JS文件（长缓存）
find . -name "*.css" | while read file; do
    upload_file "$file" "text/css" "max-age=31536000"
done

find . -name "*.js" | while read file; do
    upload_file "$file" "application/javascript" "max-age=31536000"
done

# 上传图片文件（长缓存）
find . -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.svg" -o -name "*.ico" | while read file; do
    case "$file" in
        *.png) content_type="image/png" ;;
        *.jpg|*.jpeg) content_type="image/jpeg" ;;
        *.svg) content_type="image/svg+xml" ;;
        *.ico) content_type="image/x-icon" ;;
    esac
    upload_file "$file" "$content_type" "max-age=31536000"
done
EOF

    chmod +x upload_optimized.sh
}

create_upload_script
./upload_optimized.sh

cd ../..
```

### 2.3 配置CDN加速

```bash
echo "🌐 配置CDN加速..."

# 创建CDN分发
    --Domain "cdn.yourdomain.com" \
    --ServiceType "web" \
    --Origin '{
        "Origins": ["'$PROD_COS_BUCKET_URL'"],
        "OriginType": "cos",
        "ServerName": "'$PROD_COS_BUCKET_URL'"
    }' \
    --ProjectId 0

echo "CDN配置完成，请在控制台完成域名验证"
echo "控制台地址: https://console.cloud.tencent.com/cdn"
```

## ⚡ 生产后端部署

### 3.1 构建生产镜像

```bash
echo "⚡ 构建生产后端镜像..."

# 为生产环境重新构建镜像
services=("website-api" "user-service" "notification-service")

for service in "${services[@]}"; do
    echo "构建 $service 生产镜像..."
    
    cd "backend/$service"
    
    # 创建生产Dockerfile
    cat > Dockerfile.prod << 'EOF'
FROM golang:1.21-alpine AS builder

# 安装必要工具
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# 复制go mod文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o app main.go

# 最终镜像
FROM scratch

# 复制时区信息和CA证书
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/app /app

# 设置时区
ENV TZ=Asia/Shanghai

EXPOSE 8080

CMD ["/app"]
EOF
    
    # 构建生产镜像
    docker build -f Dockerfile.prod -t "oh-i-have-that/$service:prod" .
    
    # 标记为最新版本
    docker tag "oh-i-have-that/$service:prod" "oh-i-have-that/$service:latest"
    
    cd ../..
done

# 查看镜像大小
echo "=== 生产镜像大小 ==="
docker images | grep oh-i-have-that
```

### 3.2 推送生产镜像

```bash
echo "📤 推送生产镜像..."

if [ -n "$PROD_CONTAINER_REGISTRY_URL" ]; then
    # 登录容器注册表
    echo "请确保已登录到生产容器注册表"
    
    for service in "${services[@]}"; do
        echo "推送 $service 镜像..."
        
        # 标记生产镜像
        docker tag "oh-i-have-that/$service:prod" "$PROD_CONTAINER_REGISTRY_URL/$service:prod"
        docker tag "oh-i-have-that/$service:prod" "$PROD_CONTAINER_REGISTRY_URL/$service:latest"
        
        # 推送镜像
        docker push "$PROD_CONTAINER_REGISTRY_URL/$service:prod"
        docker push "$PROD_CONTAINER_REGISTRY_URL/$service:latest"
    done
    
    echo "✅ 生产镜像推送完成"
else
    echo "⚠️  生产容器注册表未配置"
fi
```

### 3.3 部署生产云函数

```bash
echo "☁️ 部署生产云函数..."

# 创建生产部署目录
mkdir -p deploy/prod

for service in "${services[@]}"; do
    echo "部署 $service 到生产环境..."
    
    mkdir -p "deploy/prod/$service"
    cd "deploy/prod/$service"
    
    # 创建生产云函数代码
    cat > main.py << EOF
import json
import logging
import os
import time

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main_handler(event, context):
    """
    生产环境 $service 云函数
    """
    start_time = time.time()
    
    try:
        # 记录请求信息
        logger.info(f"Processing request for $service")
        logger.info(f"Event: {json.dumps(event, default=str)}")
        
        # 获取请求信息
        path = event.get('path', '/')
        method = event.get('httpMethod', 'GET')
        headers = event.get('headers', {})
        
        # 处理CORS预检请求
        if method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Requested-With',
                    'Access-Control-Max-Age': '86400'
                },
                'body': ''
            }
        
        # 业务逻辑处理
        response_data = process_${service}_request(path, method, event)
        
        # 构建响应
        response = {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'X-Response-Time': str(int((time.time() - start_time) * 1000)) + 'ms'
            },
            'body': json.dumps(response_data, ensure_ascii=False)
        }
        
        logger.info(f"Request processed successfully in {time.time() - start_time:.3f}s")
        return response
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal Server Error',
                'message': str(e) if os.getenv('DEBUG') else 'An error occurred',
                'timestamp': int(time.time())
            }, ensure_ascii=False)
        }

def process_${service}_request(path, method, event):
    """
    处理 $service 的具体业务逻辑
    """
    if '$service' == 'website-api':
        if '/health' in path:
            return {
                'status': 'healthy',
                'service': 'website-api',
                'version': '1.0.0',
                'timestamp': int(time.time())
            }
        elif '/api/v1' in path:
            return {
                'message': 'Website API is running',
                'path': path,
                'method': method
            }
    
    elif '$service' == 'user-service':
        if '/users' in path:
            return {
                'users': [
                    {'id': 1, 'name': 'Production User', 'email': 'user@yourdomain.com'}
                ],
                'total': 1
            }
    
    elif '$service' == 'notification-service':
        if '/notifications' in path:
            return {
                'notifications': [
                    {'id': 1, 'message': 'Welcome to production', 'read': False}
                ],
                'total': 1
            }
    
    return {
        'message': f'{service} is running',
        'path': path,
        'method': method
    }
EOF
    
    # 打包函数
    zip -r "${service}-prod.zip" main.py
    
    # 部署云函数
        --FunctionName "${service}-prod" \
        --Runtime "Python3.9" \
        --Handler "main.main_handler" \
        --Code '{"ZipFile": "'$(base64 -i "${service}-prod.zip")'"}' \
        --Description "Production ${service} Service" \
        --Timeout 60 \
        --MemorySize 256 \
        --Environment '{
            "Variables": {
                "ENV": "production",
                "SERVICE_NAME": "'$service'",
                "LOG_LEVEL": "INFO"
            }
        }' \
        --DeadLetterConfig '{
            "Type": "CMQ",
            "Name": "dlq-'$service'-prod"
        }'
    
    cd ../../..
done
```

## 🌉 生产API网关配置

### 4.1 创建生产API服务

```bash
echo "🌉 创建生产API服务..."

# 创建生产API服务
    --ServiceName "oh-i-have-that-prod" \
    --ServiceDesc "Oh I Have That Production Environment" \
    --Protocol "https" \
    --NetTypes '["INNER", "OUTER"]' \
    --query 'ServiceId' --output text)

echo "生产API服务ID: $PROD_API_SERVICE_ID"

# 配置服务级别的限流
    --ServiceId "$PROD_API_SERVICE_ID" \
    --ServiceName "oh-i-have-that-prod" \
    --ServiceDesc "Production API with rate limiting" \
    --Protocol "https"
```

### 4.2 配置生产API路由

```bash
echo "🔗 配置生产API路由..."

# 配置website-api路由
    --ServiceId "$PROD_API_SERVICE_ID" \
    --ApiName "website-api-prod" \
    --ApiDesc "Production Website API" \
    --ApiType "NORMAL" \
    --AuthType "NONE" \
    --Protocol "HTTPS" \
    --RequestConfig '{
        "Path": "/api/v1/{proxy+}",
        "Method": "ANY"
    }' \
    --ServiceType "SCF" \
    --ServiceConfig '{
        "Product": "SCF",
        "UniqVpcId": "",
        "Url": "",
        "Path": "/",
        "Method": "POST",
        "UpstreamId": "",
        "CosConfig": {
            "Action": "GetObject",
            "BucketName": "",
            "Authorization": true,
            "PathMatchMode": "BackEndPath"
        }
    }' \
    --RequestParameters '[
        {
            "Name": "proxy",
            "Position": "PATH",
            "Type": "string",
            "DefaultValue": "",
            "Required": true,
            "Desc": "Proxy path parameter"
        }
    ]' \
    --ServiceTimeout 30000

# 配置其他服务路由...
# (类似的配置用于user-service和notification-service)
```

### 4.3 配置API安全策略

```bash
echo "🔒 配置API安全策略..."

# 配置IP白名单（如果需要）
#     --ServiceId "$PROD_API_SERVICE_ID" \
#     --SecretIds '["your-secret-id"]'

# 配置使用计划和API密钥
    --UsagePlanName "prod-usage-plan" \
    --UsagePlanDesc "Production usage plan" \
    --MaxRequestNum 10000 \
    --MaxRequestNumPreSec 100 \
    --query 'UsagePlanId' --output text)

echo "使用计划ID: $USAGE_PLAN_ID"

# 绑定使用计划到API服务
    --UsagePlanId "$USAGE_PLAN_ID" \
    --ServiceId "$PROD_API_SERVICE_ID" \
    --Environment "release" \
    --BindType "API"
```

### 4.4 发布生产API

```bash
echo "🚀 发布生产API..."

# 发布到生产环境
    --ServiceId "$PROD_API_SERVICE_ID" \
    --EnvironmentName "release" \
    --ReleaseDesc "Production release v1.0.0"

# 获取生产API地址
PROD_API_GATEWAY_URL="https://${PROD_API_SERVICE_ID}-${TENCENTCLOUD_REGION}.apigw.tencentcs.com/release"
echo "生产API地址: $PROD_API_GATEWAY_URL"
```

## 🔍 监控和日志配置

### 5.1 配置云监控

```bash
echo "📊 配置云监控..."

# 创建告警策略
    --Module "monitor" \
    --PolicyName "prod-scf-alarm" \
    --MonitorType "MT_QCE" \
    --Namespace "QCE/SCF_V2" \
    --Remark "Production SCF monitoring" \
    --Conditions '[
        {
            "MetricName": "Duration",
            "Period": 300,
            "Operator": "gt",
            "Value": "30000",
            "ContinuePeriod": 2,
            "NoticeFrequency": 7200
        },
        {
            "MetricName": "Error",
            "Period": 300,
            "Operator": "gt", 
            "Value": "10",
            "ContinuePeriod": 1,
            "NoticeFrequency": 3600
        }
    ]'

echo "监控告警配置完成"
```

### 5.2 配置日志收集

```bash
echo "📝 配置日志收集..."

# 为每个云函数配置日志
for service in "${services[@]}"; do
    echo "配置 $service 日志收集..."
    
    # 更新函数配置启用日志
        --FunctionName "${service}-prod" \
        --ClsLogsetId "your-logset-id" \
        --ClsTopicId "your-topic-id"
done

echo "日志收集配置完成"
echo "日志查看: https://console.cloud.tencent.com/cls"
```

## 🌐 域名和SSL配置

### 6.1 配置自定义域名

```bash
echo "🌐 配置自定义域名..."

# 为API网关配置自定义域名
    --ServiceId "$PROD_API_SERVICE_ID" \
    --DomainName "api.yourdomain.com" \
    --CertificateId "your-ssl-cert-id" \
    --IsDefaultMapping false \
    --PathMappings '[
        {
            "Path": "/",
            "Environment": "release"
        }
    ]'

echo "API域名配置完成: https://api.yourdomain.com"

# 配置前端域名（通过CDN）
echo "前端域名配置: https://www.yourdomain.com"
echo "请在DNS中配置CNAME记录指向CDN域名"
```

### 6.2 SSL证书配置

```bash
echo "🔒 SSL证书配置..."

# 上传SSL证书（如果还没有）
#     --CertificatePublicKey "$(cat your-cert.pem)" \
#     --CertificatePrivateKey "$(cat your-key.pem)" \
#     --CertificateType "SVR" \
#     --Alias "yourdomain.com"

echo "SSL证书配置完成"
echo "请确保证书已正确配置到CDN和API网关"
```

## ✅ 生产环境验证

### 7.1 全面测试

```bash
echo "🧪 生产环境全面测试..."

# 创建生产测试脚本
cat > test-production.sh << 'EOF'
#!/bin/bash

echo "🚀 生产环境测试开始..."

FRONTEND_URL="https://www.yourdomain.com"
API_URL="https://api.yourdomain.com"

# 1. 前端测试
echo "1. 测试前端访问..."
if curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" | grep -q "200"; then
    echo "✅ 前端访问正常"
else
    echo "❌ 前端访问失败"
fi

# 2. API测试
echo "2. 测试API访问..."
for endpoint in "/api/v1/health" "/users" "/notifications"; do
    echo -n "测试 $endpoint: "
    if curl -s -o /dev/null -w "%{http_code}" "$API_URL$endpoint" | grep -q "200"; then
        echo "✅ 正常"
    else
        echo "❌ 失败"
    fi
done

# 3. 性能测试
echo "3. 性能测试..."
echo "前端加载时间:"
time curl -s "$FRONTEND_URL" > /dev/null

echo "API响应时间:"
time curl -s "$API_URL/api/v1/health" > /dev/null

# 4. SSL测试
echo "4. SSL证书测试..."
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

echo "🎉 生产环境测试完成"
EOF

chmod +x test-production.sh
./test-production.sh
```

### 7.2 监控检查

```bash
echo "📊 检查监控状态..."

# 检查云函数状态
echo "=== 云函数状态 ==="
for service in "${services[@]}"; do
    echo "${service}-prod: $status"
done

# 检查API网关状态
echo "=== API网关状态 ==="

# 检查告警策略
echo "=== 告警策略 ==="

echo "监控检查完成"
```

## 📋 完成检查清单

- [ ] 生产基础设施部署成功
- [ ] 安全策略配置完成
- [ ] 前端生产构建并部署
- [ ] CDN配置完成
- [ ] 后端生产镜像构建
- [ ] 云函数生产部署成功
- [ ] API网关生产配置完成
- [ ] 自定义域名配置完成
- [ ] SSL证书配置完成
- [ ] 监控和告警配置完成
- [ ] 日志收集配置完成
- [ ] 生产环境测试通过
- [ ] 性能指标满足要求

## 📊 生产环境信息

```bash
echo "=== 生产环境信息汇总 ==="
echo "前端地址: https://www.yourdomain.com"
echo "API地址: https://api.yourdomain.com"
echo "CDN地址: https://cdn.yourdomain.com"
echo "API服务ID: $PROD_API_SERVICE_ID"
echo "COS存储桶: $PROD_COS_BUCKET_NAME"
echo ""
echo "=== 管理控制台 ==="
echo "云函数: https://console.cloud.tencent.com/scf"
echo "API网关: https://console.cloud.tencent.com/apigateway"
echo "COS: https://console.cloud.tencent.com/cos"
echo "CDN: https://console.cloud.tencent.com/cdn"
echo "监控: https://console.cloud.tencent.com/monitor"
echo "日志: https://console.cloud.tencent.com/cls"
```

## 🆘 故障排除

遇到问题请查看: [生产环境部署故障排除](troubleshooting.md)

---

**🎉 生产环境部署完成！**

恭喜！你已经成功完成了从开发环境搭建到生产环境部署的完整流程。