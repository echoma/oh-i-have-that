# 🆘 测试环境部署故障排除

## COS部署问题

### 问题: COS上传失败

```bash
# 错误信息
Error: Access Denied
```

**解决方案**:

```bash
# 1. 检查腾讯云CLI配置
tccli configure list

# 2. 重新配置认证
tccli configure
# 输入正确的SecretId和SecretKey

# 3. 测试COS访问权限
tccli cos HeadBucket --Bucket "$COS_BUCKET_NAME"

# 4. 检查存储桶策略
tccli cos GetBucketAcl --Bucket "$COS_BUCKET_NAME"

# 5. 手动设置存储桶权限
tccli cos PutBucketAcl \
    --Bucket "$COS_BUCKET_NAME" \
    --ACL "public-read"
```

### 问题: 静态网站配置失败

```bash
# 错误信息
Static website hosting not enabled
```

**解决方案**:

```bash
# 1. 检查存储桶区域
echo "存储桶区域: $TENCENTCLOUD_REGION"

# 2. 重新配置静态网站托管
tccli cos PutBucketWebsite \
    --Bucket "$COS_BUCKET_NAME" \
    --WebsiteConfiguration '{
        "IndexDocument": {"Suffix": "index.html"},
        "ErrorDocument": {"Key": "error.html"},
        "RedirectAllRequestsTo": {"Protocol": "https"}
    }'

# 3. 验证配置
tccli cos GetBucketWebsite --Bucket "$COS_BUCKET_NAME"

# 4. 检查域名解析
nslookup "$COS_BUCKET_URL"
```

### 问题: 文件MIME类型错误

```bash
# 问题: CSS/JS文件无法正确加载
```

**解决方案**:

```bash
# 1. 重新上传文件并指定正确的Content-Type
upload_with_content_type() {
    local file="$1"
    local key="$2"
    local content_type="$3"
    
    tccli cos PutObject \
        --Bucket "$COS_BUCKET_NAME" \
        --Key "$key" \
        --Body "$file" \
        --ContentType "$content_type" \
        --CacheControl "max-age=31536000"
}

# 2. 批量修复文件类型
cd frontend/dist
find . -name "*.css" -exec upload_with_content_type {} {} "text/css" \;
find . -name "*.js" -exec upload_with_content_type {} {} "application/javascript" \;
find . -name "*.html" -exec upload_with_content_type {} {} "text/html" \;
cd ../..

# 3. 验证文件类型
curl -I "$COS_BUCKET_URL/assets/index.css"
```

## 云函数部署问题

### 问题: 云函数创建失败

```bash
# 错误信息
[TencentCloudSDKException] Code=ResourceInUse.FunctionName
```

**解决方案**:

```bash
# 1. 检查函数是否已存在
tccli scf ListFunctions --query 'Functions[?FunctionName==`website-api`]'

# 2. 删除现有函数
tccli scf DeleteFunction --FunctionName "website-api"

# 3. 重新创建函数
# 使用之前的创建命令

# 4. 或者更新现有函数
tccli scf UpdateFunctionCode \
    --FunctionName "website-api" \
    --Code '{"ZipFile": "'$(base64 -i website-api.zip)'"}'
```

### 问题: 函数运行时错误

```bash
# 错误信息
Runtime error or timeout
```

**解决方案**:

```bash
# 1. 检查函数日志
tccli scf GetFunctionLogs \
    --FunctionName "website-api" \
    --StartTime "2024-01-01 00:00:00" \
    --EndTime "2024-12-31 23:59:59"

# 2. 增加函数超时时间
tccli scf UpdateFunctionConfiguration \
    --FunctionName "website-api" \
    --Timeout 60 \
    --MemorySize 256

# 3. 测试函数
tccli scf Invoke \
    --FunctionName "website-api" \
    --InvocationType "RequestResponse" \
    --Payload '{"test": true}'

# 4. 修复函数代码
cat > main.py << 'EOF'
import json
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

def main_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # 处理请求
        response = {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            },
            'body': json.dumps({
                'message': 'Function is working',
                'timestamp': context.get_remaining_time_in_millis()
            })
        }
        
        logger.info(f"Returning response: {response}")
        return response
        
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
EOF
```

### 问题: 函数权限不足

```bash
# 错误信息
Permission denied
```

**解决方案**:

```bash
# 1. 创建函数执行角色
tccli cam CreateRole \
    --RoleName "SCF_QcsRole" \
    --PolicyDocument '{
        "version": "2.0",
        "statement": [
            {
                "action": "sts:AssumeRole",
                "effect": "allow",
                "principal": {
                    "service": "scf.qcloud.com"
                }
            }
        ]
    }'

# 2. 附加策略到角色
tccli cam AttachRolePolicy \
    --RoleName "SCF_QcsRole" \
    --PolicyName "QcloudSCFFullAccess"

# 3. 更新函数配置
tccli scf UpdateFunctionConfiguration \
    --FunctionName "website-api" \
    --Role "qcs::cam::uin/your-uin:role/SCF_QcsRole"
```

## API网关问题

### 问题: API网关创建失败

```bash
# 错误信息
Service limit exceeded
```

**解决方案**:

```bash
# 1. 检查现有API服务
tccli apigateway DescribeServicesStatus

# 2. 删除不用的API服务
tccli apigateway DeleteService --ServiceId "old-service-id"

# 3. 检查配额限制
echo "请检查API网关配额限制"
echo "控制台: https://console.cloud.tencent.com/apigateway"

# 4. 使用现有服务
EXISTING_SERVICE_ID="existing-service-id"
```

### 问题: API路由配置错误

```bash
# 错误信息
API configuration invalid
```

**解决方案**:

```bash
# 1. 检查API配置
tccli apigateway DescribeApi \
    --ServiceId "$API_SERVICE_ID" \
    --ApiId "$API_ID"

# 2. 修复API配置
tccli apigateway ModifyApi \
    --ServiceId "$API_SERVICE_ID" \
    --ApiId "$API_ID" \
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
        "Method": "POST"
    }'

# 3. 重新发布API
tccli apigateway ReleaseService \
    --ServiceId "$API_SERVICE_ID" \
    --EnvironmentName "test" \
    --ReleaseDesc "Fix API configuration"
```

### 问题: CORS跨域问题

```bash
# 错误信息
CORS policy blocked
```

**解决方案**:

```bash
# 1. 在云函数中添加CORS头
cat > cors_handler.py << 'EOF'
def add_cors_headers(response):
    if 'headers' not in response:
        response['headers'] = {}
    
    response['headers'].update({
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Requested-With',
        'Access-Control-Max-Age': '86400'
    })
    
    return response

def main_handler(event, context):
    # 处理OPTIONS预检请求
    if event.get('httpMethod') == 'OPTIONS':
        return add_cors_headers({
            'statusCode': 200,
            'body': ''
        })
    
    # 正常处理请求
    response = {
        'statusCode': 200,
        'body': json.dumps({'message': 'Success'})
    }
    
    return add_cors_headers(response)
EOF

# 2. 在API网关配置CORS
tccli apigateway ModifyApi \
    --ServiceId "$API_SERVICE_ID" \
    --ApiId "$API_ID" \
    --ResponseType "HTML" \
    --ResponseSuccessExample "Success" \
    --ResponseFailExample "Fail" \
    --ResponseErrorCodes '[
        {
            "Code": 200,
            "Msg": "Success",
            "Desc": "Success",
            "ConvertedCode": 200,
            "NeedConvert": false
        }
    ]'
```

## 网络连接问题

### 问题: API访问超时

```bash
# 错误信息
Connection timeout
```

**解决方案**:

```bash
# 1. 检查网络连接
ping -c 3 "$API_GATEWAY_DOMAIN"

# 2. 检查DNS解析
nslookup "$API_GATEWAY_DOMAIN"

# 3. 使用curl详细调试
curl -v -X GET "$API_GATEWAY_URL/api/v1/health"

# 4. 检查防火墙设置
# 确保443和80端口开放

# 5. 测试不同网络环境
# 尝试使用手机热点或其他网络
```

### 问题: SSL证书问题

```bash
# 错误信息
SSL certificate verify failed
```

**解决方案**:

```bash
# 1. 跳过SSL验证测试
curl -k "$API_GATEWAY_URL/api/v1/health"

# 2. 检查证书信息
openssl s_client -connect "$API_GATEWAY_DOMAIN:443" -servername "$API_GATEWAY_DOMAIN"

# 3. 更新CA证书
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install ca-certificates

# macOS
brew install ca-certificates

# 4. 配置自定义域名（如果需要）
echo "配置自定义域名和SSL证书"
echo "控制台: https://console.cloud.tencent.com/apigateway"
```

## 测试验证问题

### 问题: 端到端测试失败

```bash
# 问题: 前端无法连接后端
```

**解决方案**:

```bash
# 1. 检查前端配置
grep -r "API_URL\|baseURL" frontend/src/

# 2. 更新前端API配置
cat > frontend/src/config.js << 'EOF'
export const config = {
    apiUrl: process.env.NODE_ENV === 'production' 
        ? 'https://your-api-gateway-url/test'
        : 'http://localhost:8080',
    version: '1.0.0'
};
EOF

# 3. 重新构建前端
cd frontend
npm run build
cd ..

# 4. 重新上传前端文件
# 使用之前的上传脚本

# 5. 测试API连接
curl -X GET "$API_GATEWAY_URL/api/v1/health" \
    -H "Origin: $COS_BUCKET_URL" \
    -H "Referer: $COS_BUCKET_URL"
```

### 问题: 数据不一致

```bash
# 问题: 前后端数据格式不匹配
```

**解决方案**:

```bash
# 1. 检查API响应格式
curl -s "$API_GATEWAY_URL/users" | jq .

# 2. 统一数据格式
cat > api_response_format.py << 'EOF'
import json

def format_response(data, message="Success", code=200):
    return {
        'statusCode': code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'code': code,
            'message': message,
            'data': data,
            'timestamp': int(time.time())
        })
    }
EOF

# 3. 更新所有云函数使用统一格式
# 4. 更新前端处理逻辑
```

## 性能问题

### 问题: 响应时间过长

```bash
# 问题: API响应超过5秒
```

**解决方案**:

```bash
# 1. 优化云函数配置
tccli scf UpdateFunctionConfiguration \
    --FunctionName "website-api" \
    --Timeout 30 \
    --MemorySize 512 \
    --Environment '{
        "Variables": {
            "NODE_ENV": "production"
        }
    }'

# 2. 启用函数预置并发
tccli scf PutProvisionedConcurrencyConfig \
    --FunctionName "website-api" \
    --Qualifier "$LATEST" \
    --VersionProvisionedConcurrencyConfig '{
        "AllocatedProvisionedConcurrencyNum": 1
    }'

# 3. 优化代码
# 减少冷启动时间
# 使用连接池
# 缓存常用数据

# 4. 监控性能
tccli scf GetFunctionEventInvokeConfig \
    --FunctionName "website-api"
```

## 完整诊断脚本

创建测试环境诊断脚本 `diagnose-test-env.sh`:

```bash
#!/bin/bash

echo "🔍 诊断测试环境..."

# 检查COS
echo "=== COS检查 ==="
if [ -n "$COS_BUCKET_NAME" ]; then
    tccli cos HeadBucket --Bucket "$COS_BUCKET_NAME" && echo "✅ COS存储桶正常" || echo "❌ COS存储桶异常"
    curl -I "$COS_BUCKET_URL" && echo "✅ 静态网站正常" || echo "❌ 静态网站异常"
else
    echo "❌ COS配置缺失"
fi

# 检查云函数
echo "=== 云函数检查 ==="
for func in website-api user-service notification-service; do
    status=$(tccli scf GetFunction --FunctionName "$func" --query 'Status' --output text 2>/dev/null || echo "Not Found")
    echo "$func: $status"
done

# 检查API网关
echo "=== API网关检查 ==="
if [ -n "$API_SERVICE_ID" ]; then
    tccli apigateway DescribeService --ServiceId "$API_SERVICE_ID" --query 'ServiceName' --output text
    curl -I "$API_GATEWAY_URL/api/v1/health" && echo "✅ API网关正常" || echo "❌ API网关异常"
else
    echo "❌ API网关配置缺失"
fi

# 网络连通性测试
echo "=== 网络测试 ==="
ping -c 1 cloud.tencent.com && echo "✅ 网络连接正常" || echo "❌ 网络连接异常"

echo "🔍 诊断完成"
```

使用脚本:

```bash
chmod +x diagnose-test-env.sh
./diagnose-test-env.sh
```

---

如果以上解决方案都无法解决问题，请：

1. 查看腾讯云控制台的详细错误信息
2. 检查云函数和API网关的监控日志
3. 验证所有配置参数的正确性
4. 在项目Issues中搜索类似问题