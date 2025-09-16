# 3️⃣ 本地联合调试

## 📋 概述

本文档介绍如何在本地环境中进行前后端联合调试，包括API接口测试、端到端测试和调试工具的使用。

## 🛠️ 前置条件

### 环境要求
- 完成前端编译和测试
- 完成后端编译和测试
- Docker Desktop（用于本地数据库等依赖服务）
- Postman 或类似的API测试工具

### 验证前置条件
```bash
# 检查前端构建输出
ls -la frontend/dist/

# 检查后端二进制文件
find backend/ -name "bin" -type d -exec ls -la {} \;

# 检查Docker
docker --version
```

## 🏗️ 本地开发环境搭建

### 1. 启动依赖服务

#### 启动本地数据库（如果需要）
```bash
# 使用Docker Compose启动依赖服务
docker-compose -f docker-compose.dev.yml up -d

# 或手动启动MySQL/PostgreSQL
docker run -d \
  --name dev-mysql \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=ohihavethat \
  -p 3306:3306 \
  mysql:8.0
```

#### 启动Redis（如果需要）
```bash
docker run -d \
  --name dev-redis \
  -p 6379:6379 \
  redis:alpine
```

### 2. 配置环境变量

创建本地开发配置文件：

```bash
# 创建后端环境配置
cat > backend/.env.local << EOF
# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=password
DB_NAME=ohihavethat

# Redis配置
REDIS_HOST=localhost
REDIS_PORT=6379

# API配置
API_PORT=8080
API_HOST=0.0.0.0

# 调试模式
DEBUG=true
LOG_LEVEL=debug
EOF
```

### 3. 启动后端服务

#### 启动 User Service
```bash
cd backend/user-service

# 加载环境变量
export $(cat ../.env.local | xargs)

# 启动服务
./bin/user-service &
USER_SERVICE_PID=$!
echo "User Service PID: $USER_SERVICE_PID"
```

#### 启动 Notification Service
```bash
cd backend/notification-service

# 启动服务
./bin/notification-service &
NOTIFICATION_SERVICE_PID=$!
echo "Notification Service PID: $NOTIFICATION_SERVICE_PID"
```

#### 启动 Website API
```bash
cd backend/website-api

# 启动服务
./bin/website-api &
WEBSITE_API_PID=$!
echo "Website API PID: $WEBSITE_API_PID"
```

### 4. 启动前端开发服务器

```bash
cd frontend

# 启动开发服务器
npm run dev &
FRONTEND_PID=$!
echo "Frontend PID: $FRONTEND_PID"

# 或使用http-server提供静态文件
npx http-server dist/ -p 3000 -c-1 &
```

## 🔗 服务连接配置

### 前端API配置

更新前端配置以连接本地后端：

```javascript
// frontend/src/config/api.js
const API_CONFIG = {
  development: {
    USER_SERVICE: 'http://localhost:8081',
    NOTIFICATION_SERVICE: 'http://localhost:8082',
    WEBSITE_API: 'http://localhost:8080'
  },
  production: {
    USER_SERVICE: 'https://api.yourdomain.com/user',
    NOTIFICATION_SERVICE: 'https://api.yourdomain.com/notification',
    WEBSITE_API: 'https://api.yourdomain.com'
  }
};

export default API_CONFIG[process.env.NODE_ENV || 'development'];
```

### 跨域配置

如果遇到CORS问题，在后端服务中添加CORS头：

```go
// 在Go服务中添加CORS中间件
func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "http://localhost:3000")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        
        next.ServeHTTP(w, r)
    })
}
```

## 🧪 API接口测试

### 1. 健康检查测试

```bash
# 测试各服务健康状态
curl http://localhost:8080/health
curl http://localhost:8081/health
curl http://localhost:8082/health
```

### 2. 用户服务API测试

```bash
# 创建用户
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }'

# 获取用户信息
curl http://localhost:8081/api/users/1

# 用户登录
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### 3. 通知服务API测试

```bash
# 发送通知
curl -X POST http://localhost:8082/api/notifications \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "user_id": 1,
    "message": "测试通知",
    "type": "info"
  }'

# 获取用户通知
curl http://localhost:8082/api/notifications/user/1 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. 网站API测试

```bash
# 获取网站信息
curl http://localhost:8080/api/info

# 搜索功能
curl "http://localhost:8080/api/search?q=test"

# 上传文件
curl -X POST http://localhost:8080/api/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@test.jpg"
```

## 🔍 端到端测试

### 1. 用户注册流程测试

```bash
#!/bin/bash
# e2e-test-user-registration.sh

echo "=== 用户注册端到端测试 ==="

# 1. 注册新用户
echo "1. 注册新用户..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "e2etest",
    "email": "e2e@example.com",
    "password": "password123"
  }')

echo "注册响应: $REGISTER_RESPONSE"

# 2. 用户登录
echo "2. 用户登录..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "e2e@example.com",
    "password": "password123"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
echo "登录成功，Token: $TOKEN"

# 3. 发送欢迎通知
echo "3. 发送欢迎通知..."
NOTIFICATION_RESPONSE=$(curl -s -X POST http://localhost:8082/api/notifications \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "user_id": 1,
    "message": "欢迎注册！",
    "type": "welcome"
  }')

echo "通知响应: $NOTIFICATION_RESPONSE"

echo "=== 端到端测试完成 ==="
```

### 2. 前端集成测试

```javascript
// frontend/tests/e2e/user-flow.test.js
describe('用户流程端到端测试', () => {
  test('用户注册和登录流程', async () => {
    // 访问注册页面
    await page.goto('http://localhost:3000/register');
    
    // 填写注册表单
    await page.fill('#username', 'e2etest');
    await page.fill('#email', 'e2e@example.com');
    await page.fill('#password', 'password123');
    
    // 提交注册
    await page.click('#register-button');
    
    // 验证注册成功
    await expect(page.locator('.success-message')).toBeVisible();
    
    // 跳转到登录页面
    await page.goto('http://localhost:3000/login');
    
    // 登录
    await page.fill('#email', 'e2e@example.com');
    await page.fill('#password', 'password123');
    await page.click('#login-button');
    
    // 验证登录成功
    await expect(page.locator('.dashboard')).toBeVisible();
  });
});
```

## 🛠️ 调试工具和技巧

### 1. Go服务调试

#### 使用Delve调试器
```bash
# 安装Delve
go install github.com/go-delve/delve/cmd/dlv@latest

# 调试用户服务
cd backend/user-service
dlv debug ./cmd/main.go -- --config=config.yaml
```

#### 添加调试日志
```go
// 在Go代码中添加调试日志
import "log"

func handleRequest(w http.ResponseWriter, r *http.Request) {
    log.Printf("DEBUG: 收到请求 %s %s", r.Method, r.URL.Path)
    log.Printf("DEBUG: 请求头: %+v", r.Header)
    
    // 处理请求...
    
    log.Printf("DEBUG: 响应状态: %d", statusCode)
}
```

### 2. 前端调试

#### 浏览器开发者工具
- 使用Network标签监控API请求
- 使用Console查看JavaScript错误
- 使用Sources进行断点调试

#### 前端日志
```javascript
// 添加详细的前端日志
console.group('API请求');
console.log('URL:', url);
console.log('方法:', method);
console.log('数据:', data);
console.groupEnd();

// 使用try-catch捕获错误
try {
  const response = await fetch(url, options);
  console.log('响应:', response);
} catch (error) {
  console.error('请求失败:', error);
}
```

### 3. 网络调试

#### 使用tcpdump监控网络流量
```bash
# 监控本地API流量
sudo tcpdump -i lo0 -A -s 0 'port 8080'
```

#### 使用Wireshark分析
- 启动Wireshark
- 监听loopback接口
- 过滤HTTP流量

## 📊 性能监控

### 1. 后端性能监控

```go
// 添加性能监控中间件
func performanceMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        next.ServeHTTP(w, r)
        
        duration := time.Since(start)
        log.Printf("请求 %s %s 耗时: %v", r.Method, r.URL.Path, duration)
    })
}
```

### 2. 前端性能监控

```javascript
// 监控API请求性能
const performanceMonitor = {
  async request(url, options) {
    const start = performance.now();
    
    try {
      const response = await fetch(url, options);
      const end = performance.now();
      
      console.log(`API请求 ${url} 耗时: ${end - start}ms`);
      return response;
    } catch (error) {
      const end = performance.now();
      console.error(`API请求 ${url} 失败，耗时: ${end - start}ms`, error);
      throw error;
    }
  }
};
```

## 🚀 自动化调试脚本

```bash
#!/bin/bash
# scripts/dev/start-local-env.sh

echo "=== 启动本地开发环境 ==="

# 1. 启动依赖服务
echo "启动依赖服务..."
docker-compose -f docker-compose.dev.yml up -d

# 2. 等待服务就绪
echo "等待数据库就绪..."
sleep 10

# 3. 启动后端服务
echo "启动后端服务..."
cd backend
./scripts/start-all-services.sh &

# 4. 启动前端服务
echo "启动前端服务..."
cd frontend
npm run dev &

# 5. 等待服务启动
sleep 5

# 6. 运行健康检查
echo "运行健康检查..."
./scripts/dev/health-check.sh

echo "=== 本地开发环境启动完成 ==="
echo "前端地址: http://localhost:3000"
echo "API地址: http://localhost:8080"
```

## 🐛 常见问题

### 端口冲突
```bash
# 查找占用端口的进程
lsof -i :8080
lsof -i :3000

# 杀死进程
kill -9 PID
```

### 服务无法连接
```bash
# 检查服务状态
ps aux | grep user-service
ps aux | grep notification-service

# 检查端口监听
netstat -tlnp | grep :8080
```

### 数据库连接问题
```bash
# 测试数据库连接
mysql -h localhost -P 3306 -u root -p

# 检查Docker容器状态
docker ps
docker logs dev-mysql
```

## ✅ 验证清单

- [ ] 依赖服务启动成功
- [ ] 所有后端服务运行正常
- [ ] 前端开发服务器启动
- [ ] API接口测试通过
- [ ] 端到端测试通过
- [ ] 跨域配置正确
- [ ] 调试工具配置完成
- [ ] 性能监控正常

## 📝 下一步

本地联合调试完成后，继续进行 [前端打包发布](./04-frontend-package-deploy.md)。