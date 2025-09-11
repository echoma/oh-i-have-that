# 🆘 生产环境部署故障排除

## 基础设施部署问题

### 问题: 生产环境初始化失败

```bash
# 错误信息
Error: Workspace "prod" doesn't exist
```

**解决方案**:

```bash
# 1. 创建生产工作空间
cd infrastructure
terraform workspace new prod

# 2. 验证工作空间
terraform workspace list
terraform workspace show

# 3. 初始化生产环境
terraform init -reconfigure

# 4. 检查生产配置文件
ls -la environments/prod/
cat environments/prod/terraform.tfvars
```

### 问题: 生产资源配额不足

```bash
# 错误信息
Quota exceeded for production resources
```

**解决方案**:

```bash
# 1. 检查当前配额使用情况
echo "请检查以下资源配额："
echo "- 云函数配额"
echo "- API网关配额" 
echo "- COS存储配额"
echo "- CDN配额"

# 2. 申请配额提升
echo "提交工单申请配额提升"
echo "工单地址: https://console.cloud.tencent.com/workorder"

# 3. 优化资源使用
# 删除测试环境不必要的资源
terraform workspace select test
terraform destroy -target=module.unused_resources

# 4. 分批部署
terraform apply -target=module.network -var-file="environments/prod/terraform.tfvars"
terraform apply -target=module.cos -var-file="environments/prod/terraform.tfvars"
```

## 安全配置问题

### 问题: COS安全策略配置失败

```bash
# 错误信息
Policy format invalid
```

**解决方案**:

```bash
# 1. 验证策略格式
cat > valid_policy.json << 'EOF'
{
    "version": "2.0",
    "statement": [
        {
            "principal": {"qcs": ["qcs::cam::anyone:anyone"]},
            "effect": "allow",
            "action": ["cos:GetObject"],
            "resource": ["qcs::cos:ap-guangzhou:1234567890:bucket-name/*"],
            "condition": {
                "string_like": {
                    "cos:x-cos-referer": ["https://*.yourdomain.com"]
                }
            }
        }
    ]
}
EOF

# 2. 应用正确的策略
tccli cos PutBucketPolicy \
    --Bucket "$PROD_COS_BUCKET_NAME" \
    --Policy "$(cat valid_policy.json)"

# 3. 验证策略
tccli cos GetBucketPolicy --Bucket "$PROD_COS_BUCKET_NAME"
```

### 问题: HTTPS重定向不生效

```bash
# 问题: HTTP请求没有自动重定向到HTTPS
```

**解决方案**:

```bash
# 1. 检查COS网站配置
tccli cos GetBucketWebsite --Bucket "$PROD_COS_BUCKET_NAME"

# 2. 重新配置HTTPS重定向
tccli cos PutBucketWebsite \
    --Bucket "$PROD_COS_BUCKET_NAME" \
    --WebsiteConfiguration '{
        "IndexDocument": {"Suffix": "index.html"},
        "ErrorDocument": {"Key": "index.html"},
        "RedirectAllRequestsTo": {"Protocol": "https"}
    }'

# 3. 在CDN层面配置HTTPS重定向
echo "在CDN控制台配置HTTPS重定向"
echo "控制台: https://console.cloud.tencent.com/cdn"

# 4. 测试重定向
curl -I http://yourdomain.com
```

## 前端部署问题

### 问题: 生产构建失败

```bash
# 错误信息
Build failed in production mode
```

**解决方案**:

```bash
# 1. 检查环境变量
echo "NODE_ENV: $NODE_ENV"
echo "VITE_API_URL: $VITE_API_URL"

# 2. 清理并重新安装依赖
cd frontend
rm -rf node_modules package-lock.json
npm cache clean --force
npm install

# 3. 检查生产配置
cat package.json | jq '.scripts.build'

# 4. 分析构建错误
npm run build -- --verbose

# 5. 修复常见问题
# 检查TypeScript错误
npm run type-check

# 检查ESLint错误
npm run lint

# 6. 使用备用构建方法
NODE_OPTIONS="--max-old-space-size=4096" npm run build
```

### 问题: 静态资源404错误

```bash
# 问题: CSS/JS文件返回404
```

**解决方案**:

```bash
# 1. 检查文件是否正确上传
tccli cos GetObject \
    --Bucket "$PROD_COS_BUCKET_NAME" \
    --Key "assets/index.css" \
    --OutputFile "/tmp/test.css"

# 2. 检查文件路径
find frontend/dist -name "*.css" -o -name "*.js" | head -10

# 3. 重新上传缺失文件
cd frontend/dist
for file in $(find . -name "*.css" -o -name "*.js"); do
    key=${file#./}
    echo "上传: $key"
    tccli cos PutObject \
        --Bucket "$PROD_COS_BUCKET_NAME" \
        --Key "$key" \
        --Body "$file"
done
cd ../..

# 4. 检查CDN缓存
echo "清理CDN缓存"
echo "控制台: https://console.cloud.tencent.com/cdn"
```

### 问题: CDN配置问题

```bash
# 错误信息
CDN domain verification failed
```

**解决方案**:

```bash
# 1. 检查域名所有权验证
echo "请完成域名所有权验证"
echo "方法1: DNS验证 - 添加指定的TXT记录"
echo "方法2: 文件验证 - 上传验证文件到网站根目录"

# 2. 检查CNAME配置
nslookup cdn.yourdomain.com

# 3. 手动配置CDN
cat > cdn_config.json << 'EOF'
{
    "Domain": "cdn.yourdomain.com",
    "ServiceType": "web",
    "Origin": {
        "Origins": ["your-cos-bucket.cos.ap-guangzhou.myqcloud.com"],
        "OriginType": "cos",
        "ServerName": "your-cos-bucket.cos.ap-guangzhou.myqcloud.com"
    },
    "Cache": {
        "SimpleCache": {
            "CacheRules": [
                {
                    "CacheType": "file",
                    "CacheContents": ["jpg", "png", "gif", "css", "js"],
                    "CacheTime": 31536000
                },
                {
                    "CacheType": "file", 
                    "CacheContents": ["html"],
                    "CacheTime": 300
                }
            ]
        }
    }
}
EOF

# 4. 等待CDN部署完成
echo "CDN部署通常需要5-10分钟"
```

## 后端部署问题

### 问题: 生产镜像构建失败

```bash
# 错误信息
Docker build failed in production
```

**解决方案**:

```bash
# 1. 检查Dockerfile.prod语法
cd backend/website-api
docker build --no-cache -f Dockerfile.prod -t test-build .

# 2. 分步构建调试
docker build --target builder -f Dockerfile.prod -t debug-builder .
docker run -it debug-builder /bin/sh

# 3. 检查Go模块
go mod tidy
go mod verify

# 4. 修复构建问题
cat > Dockerfile.prod << 'EOF'
FROM golang:1.21-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要工具
RUN apk add --no-cache git ca-certificates tzdata

# 设置Go环境
ENV GO111MODULE=on
ENV GOPROXY=https://goproxy.cn,direct

# 复制go mod文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o app main.go

# 最终镜像
FROM scratch

# 复制必要文件
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/app /app

# 设置环境变量
ENV TZ=Asia/Shanghai

EXPOSE 8080

CMD ["/app"]
EOF

cd ../..
```

### 问题: 云函数部署超时

```bash
# 错误信息
Function deployment timeout
```

**解决方案**:

```bash
# 1. 减小部署包大小
cd deploy/prod/website-api

# 只包含必要文件
cat > .zipignore << 'EOF'
*.pyc
__pycache__/
.git/
.gitignore
README.md
tests/
EOF

# 重新打包
zip -r website-api-prod.zip main.py -x@.zipignore

# 2. 分批部署函数
for service in website-api user-service notification-service; do
    echo "部署 $service..."
    # 部署单个函数
    sleep 30  # 等待间隔
done

# 3. 使用COS上传大包
# 如果包大于50MB，先上传到COS
tccli cos PutObject \
    --Bucket "$PROD_COS_BUCKET_NAME" \
    --Key "functions/website-api-prod.zip" \
    --Body "website-api-prod.zip"

# 然后从COS部署
tccli scf CreateFunction \
    --FunctionName "website-api-prod" \
    --Code '{
        "CosBucketName": "'$PROD_COS_BUCKET_NAME'",
        "CosObjectName": "functions/website-api-prod.zip"
    }'

cd ../../..
```

### 问题: 云函数运行时错误

```bash
# 错误信息
Runtime error in production function
```

**解决方案**:

```bash
# 1. 检查函数日志
tccli scf GetFunctionLogs \
    --FunctionName "website-api-prod" \
    --StartTime "$(date -d '1 hour ago' '+%Y-%m-%d %H:%M:%S')" \
    --EndTime "$(date '+%Y-%m-%d %H:%M:%S')"

# 2. 增加错误处理和日志
cat > enhanced_main.py << 'EOF'
import json
import logging
import traceback
import os
from datetime import datetime

# 配置详细日志
logging.basicConfig(
    level=logging.DEBUG if os.getenv('DEBUG') else logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main_handler(event, context):
    """
    增强的云函数处理器
    """
    request_id = context.request_id if hasattr(context, 'request_id') else 'unknown'
    
    try:
        logger.info(f"[{request_id}] Function started")
        logger.debug(f"[{request_id}] Event: {json.dumps(event, default=str)}")
        
        # 验证输入
        if not isinstance(event, dict):
            raise ValueError("Invalid event format")
        
        # 处理请求
        result = process_request(event, context, request_id)
        
        logger.info(f"[{request_id}] Function completed successfully")
        return result
        
    except Exception as e:
        error_msg = str(e)
        error_trace = traceback.format_exc()
        
        logger.error(f"[{request_id}] Error: {error_msg}")
        logger.error(f"[{request_id}] Traceback: {error_trace}")
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal Server Error',
                'message': error_msg if os.getenv('DEBUG') else 'An error occurred',
                'requestId': request_id,
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def process_request(event, context, request_id):
    """处理具体请求逻辑"""
    # 实现具体业务逻辑
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'message': 'Success',
            'requestId': request_id
        })
    }
EOF

# 3. 更新函数配置
tccli scf UpdateFunctionConfiguration \
    --FunctionName "website-api-prod" \
    --Timeout 60 \
    --MemorySize 512 \
    --Environment '{
        "Variables": {
            "DEBUG": "false",
            "LOG_LEVEL": "INFO"
        }
    }'
```

## API网关问题

### 问题: 生产API服务创建失败

```bash
# 错误信息
Service name already exists
```

**解决方案**:

```bash
# 1. 检查现有服务
tccli apigateway DescribeServicesStatus | grep "oh-i-have-that"

# 2. 使用唯一服务名
TIMESTAMP=$(date +%s)
PROD_SERVICE_NAME="oh-i-have-that-prod-$TIMESTAMP"

# 3. 创建服务
PROD_API_SERVICE_ID=$(tccli apigateway CreateService \
    --ServiceName "$PROD_SERVICE_NAME" \
    --ServiceDesc "Production API Service" \
    --Protocol "https" \
    --query 'ServiceId' --output text)

# 4. 或者删除冲突的服务
# tccli apigateway DeleteService --ServiceId "conflicting-service-id"
```

### 问题: API路由配置错误

```bash
# 错误信息
API path conflict or invalid configuration
```

**解决方案**:

```bash
# 1. 检查现有API配置
tccli apigateway DescribeApisStatus \
    --ServiceId "$PROD_API_SERVICE_ID"

# 2. 删除冲突的API
# tccli apigateway DeleteApi \
#     --ServiceId "$PROD_API_SERVICE_ID" \
#     --ApiId "conflicting-api-id"

# 3. 使用正确的路径配置
create_api_with_correct_config() {
    local api_name="$1"
    local path_pattern="$2"
    local function_name="$3"
    
    tccli apigateway CreateApi \
        --ServiceId "$PROD_API_SERVICE_ID" \
        --ApiName "$api_name" \
        --ApiType "NORMAL" \
        --AuthType "NONE" \
        --Protocol "HTTPS" \
        --RequestConfig "{
            \"Path\": \"$path_pattern\",
            \"Method\": \"ANY\"
        }" \
        --ServiceType "SCF" \
        --ServiceConfig "{
            \"Product\": \"SCF\",
            \"UniqVpcId\": \"\",
            \"Url\": \"\",
            \"Path\": \"/\",
            \"Method\": \"POST\"
        }"
}

# 4. 重新创建API
create_api_with_correct_config "website-api-prod" "/api/v1/{proxy+}" "website-api-prod"
create_api_with_correct_config "user-service-prod" "/users/{proxy+}" "user-service-prod"
```

### 问题: API限流配置问题

```bash
# 问题: 生产环境请求被限流
```

**解决方案**:

```bash
# 1. 检查使用计划配置
tccli apigateway DescribeUsagePlansStatus

# 2. 调整限流配置
tccli apigateway ModifyUsagePlan \
    --UsagePlanId "$USAGE_PLAN_ID" \
    --UsagePlanName "prod-usage-plan-updated" \
    --MaxRequestNum 100000 \
    --MaxRequestNumPreSec 1000

# 3. 创建VIP使用计划
VIP_USAGE_PLAN_ID=$(tccli apigateway CreateUsagePlan \
    --UsagePlanName "prod-vip-plan" \
    --UsagePlanDesc "VIP usage plan for production" \
    --MaxRequestNum 1000000 \
    --MaxRequestNumPreSec 10000 \
    --query 'UsagePlanId' --output text)

# 4. 绑定VIP计划
tccli apigateway BindEnvironment \
    --UsagePlanId "$VIP_USAGE_PLAN_ID" \
    --ServiceId "$PROD_API_SERVICE_ID" \
    --Environment "release"
```

## 域名和SSL问题

### 问题: 自定义域名配置失败

```bash
# 错误信息
Domain verification failed
```

**解决方案**:

```bash
# 1. 验证域名所有权
echo "请完成域名验证："
echo "方法1: 添加TXT记录到DNS"
echo "方法2: 上传验证文件到域名根目录"

# 2. 检查DNS配置
nslookup api.yourdomain.com
dig api.yourdomain.com

# 3. 等待DNS传播
echo "DNS传播可能需要24-48小时"

# 4. 重新尝试配置
tccli apigateway CreateDomain \
    --ServiceId "$PROD_API_SERVICE_ID" \
    --DomainName "api.yourdomain.com" \
    --CertificateId "your-ssl-cert-id" \
    --IsDefaultMapping false \
    --PathMappings '[{
        "Path": "/",
        "Environment": "release"
    }]'
```

### 问题: SSL证书问题

```bash
# 错误信息
SSL certificate invalid or expired
```

**解决方案**:

```bash
# 1. 检查证书有效期
echo | openssl s_client -servername api.yourdomain.com -connect api.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# 2. 重新申请证书
echo "申请新的SSL证书"
echo "控制台: https://console.cloud.tencent.com/ssl"

# 3. 上传新证书
# tccli ssl UploadCertificate \
#     --CertificatePublicKey "$(cat new-cert.pem)" \
#     --CertificatePrivateKey "$(cat new-key.pem)" \
#     --CertificateType "SVR" \
#     --Alias "api.yourdomain.com"

# 4. 更新域名配置
# tccli apigateway ModifyDomain \
#     --ServiceId "$PROD_API_SERVICE_ID" \
#     --DomainName "api.yourdomain.com" \
#     --CertificateId "new-cert-id"
```

## 监控和日志问题

### 问题: 监控告警不生效

```bash
# 问题: 没有收到告警通知
```

**解决方案**:

```bash
# 1. 检查告警策略
tccli monitor DescribeAlarmPolicies \
    --Module "monitor" \
    --query 'Policies[?PolicyName==`prod-scf-alarm`]'

# 2. 配置通知渠道
tccli monitor CreateAlarmNotice \
    --Name "prod-alarm-notice" \
    --NoticeType "ALL" \
    --NoticeLanguage "zh-CN" \
    --UserNotices '[{
        "ReceiverType": "USER",
        "StartTime": 0,
        "EndTime": 86399,
        "NoticeWays": ["EMAIL", "SMS"],
        "UserIds": [123456789],
        "GroupIds": [],
        "PhoneOrder": [123456789],
        "PhoneCircleTimes": 2,
        "PhoneInnerInterval": 60,
        "PhoneCircleInterval": 300,
        "NeedPhoneArriveNotice": 1
    }]'

# 3. 绑定告警策略和通知
tccli monitor BindingPolicyObject \
    --Module "monitor" \
    --GroupId "alarm-policy-group-id" \
    --PolicyId "alarm-policy-id" \
    --InstanceGroupId "instance-group-id"

# 4. 测试告警
echo "手动触发告警进行测试"
```

### 问题: 日志收集异常

```bash
# 问题: 无法查看云函数日志
```

**解决方案**:

```bash
# 1. 检查CLS配置
tccli cls DescribeLogsets
tccli cls DescribeTopics --LogsetId "your-logset-id"

# 2. 重新配置函数日志
for service in website-api user-service notification-service; do
    tccli scf UpdateFunctionConfiguration \
        --FunctionName "${service}-prod" \
        --ClsLogsetId "your-logset-id" \
        --ClsTopicId "your-topic-id"
done

# 3. 检查日志权限
echo "确保云函数有写入CLS的权限"

# 4. 手动查看日志
tccli cls SearchLog \
    --LogsetId "your-logset-id" \
    --TopicIds '["your-topic-id"]' \
    --StartTime "$(date -d '1 hour ago' +%s)" \
    --EndTime "$(date +%s)" \
    --Query "*"
```

## 性能问题

### 问题: 生产环境响应慢

```bash
# 问题: API响应时间超过5秒
```

**解决方案**:

```bash
# 1. 优化云函数配置
for service in website-api user-service notification-service; do
    tccli scf UpdateFunctionConfiguration \
        --FunctionName "${service}-prod" \
        --Timeout 30 \
        --MemorySize 1024 \
        --Environment '{
            "Variables": {
                "NODE_ENV": "production",
                "PYTHONUNBUFFERED": "1"
            }
        }'
done

# 2. 启用预置并发
tccli scf PutProvisionedConcurrencyConfig \
    --FunctionName "website-api-prod" \
    --Qualifier "\$LATEST" \
    --VersionProvisionedConcurrencyConfig '{
        "AllocatedProvisionedConcurrencyNum": 5
    }'

# 3. 优化代码性能
# 添加缓存、连接池等优化

# 4. 配置CDN缓存
echo "优化CDN缓存策略"
echo "控制台: https://console.cloud.tencent.com/cdn"
```

## 完整生产诊断脚本

创建生产环境诊断脚本 `diagnose-production.sh`:

```bash
#!/bin/bash

echo "🔍 生产环境诊断开始..."

# 检查基础设施
echo "=== 基础设施检查 ==="
cd infrastructure
terraform workspace show
terraform state list | head -10
cd ..

# 检查域名解析
echo "=== 域名解析检查 ==="
nslookup www.yourdomain.com
nslookup api.yourdomain.com

# 检查SSL证书
echo "=== SSL证书检查 ==="
echo | openssl s_client -servername www.yourdomain.com -connect www.yourdomain.com:443 2>/dev/null | openssl x509 -noout -subject -dates

# 检查云函数状态
echo "=== 云函数状态 ==="
for service in website-api user-service notification-service; do
    status=$(tccli scf GetFunction --FunctionName "${service}-prod" --query 'Status' --output text 2>/dev/null || echo "Not Found")
    echo "${service}-prod: $status"
done

# 检查API网关
echo "=== API网关检查 ==="
curl -I https://api.yourdomain.com/api/v1/health

# 检查CDN状态
echo "=== CDN状态检查 ==="
curl -I https://www.yourdomain.com

# 性能测试
echo "=== 性能测试 ==="
echo "前端加载时间:"
time curl -s https://www.yourdomain.com > /dev/null

echo "API响应时间:"
time curl -s https://api.yourdomain.com/api/v1/health > /dev/null

echo "🔍 生产环境诊断完成"
```

使用脚本:

```bash
chmod +x diagnose-production.sh
./diagnose-production.sh
```

## 紧急回滚步骤

如果生产环境出现严重问题：

```bash
# 1. 快速回滚到上一个版本
echo "🚨 执行紧急回滚..."

# 回滚云函数
for service in website-api user-service notification-service; do
    echo "回滚 $service..."
    tccli scf UpdateFunctionCode \
        --FunctionName "${service}-prod" \
        --Code '{"ZipFile": "'$(base64 -i "backup/${service}-last-good.zip")'"}'
done

# 2. 回滚前端
echo "回滚前端到备份版本..."
# 从备份恢复前端文件

# 3. 切换到备用环境
echo "如有必要，切换到备用环境"

# 4. 通知相关人员
echo "通知运维和开发团队"
```

---

如果以上解决方案都无法解决问题，请：

1. 查看腾讯云控制台的详细监控和日志
2. 检查所有配置的正确性和一致性
3. 联系腾讯云技术支持
4. 在项目Issues中报告问题