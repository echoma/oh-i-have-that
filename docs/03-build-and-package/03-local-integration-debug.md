# 3️⃣ 本地联合调试

## 📋 概述

本文档介绍如何在本地环境中进行前后端联合调试，包括API接口测试、端到端测试和调试工具的使用。

## 🛠️ 前置条件

### 环境要求
- 完成前端编译和测试
- 完成后端编译和测试
- Docker Desktop（用于本地数据库等依赖服务）
- curl 或 Postman（用于API测试）

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

#### 使用Docker启动数据库服务
```bash
# 启动MySQL（如果项目需要）
docker run -d \
  --name dev-mysql \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=ohihavethat \
  -p 3306:3306 \
  mysql:8.0

# 启动Redis（如果项目需要）
docker run -d \
  --name dev-redis \
  -p 6379:6379 \
  redis:alpine
```

#### 或使用Docker Compose（如果配置了）
```bash
# 如果项目根目录有docker-compose.dev.yml
docker-compose -f docker-compose.dev.yml up -d
```

### 2. 配置环境变量

创建本地开发配置：

```bash
# 创建后端环境配置文件
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

# 服务端口配置
USER_SERVICE_PORT=8081
NOTIFICATION_SERVICE_PORT=8082
WEBSITE_API_PORT=8080

# 调试模式
DEBUG=true
LOG_LEVEL=debug
EOF
```

### 3. 启动后端服务

#### 方式一：手动启动各服务
```bash
# 启动User Service
cd backend/user-service
export $(cat ../.env.local | xargs)
./bin/user-service &
USER_SERVICE_PID=$!

# 启动Notification Service  
cd ../notification-service
./bin/notification-service &
NOTIFICATION_SERVICE_PID=$!

# 启动Website API
cd ../website-api
./bin/website-api &
WEBSITE_API_PID=$!

echo "服务PID: User=$USER_SERVICE_PID, Notification=$NOTIFICATION_SERVICE_PID, API=$WEBSITE_API_PID"
```

#### 方式二：使用启动脚本（推荐）
```bash
# 如果项目有启动脚本
./scripts/dev/start-backend-services.sh

# 或创建简单的启动脚本
cat > start-local-backend.sh << 'EOF'
#!/bin/bash
set -e

echo "启动后端服务..."

# 加载环境变量
export $(cat backend/.env.local | xargs)

# 启动服务
cd backend/user-service && ./bin/user-service &
cd ../notification-service && ./bin/notification-service &  
cd ../website-api && ./bin/website-api &

echo "所有后端服务已启动"
echo "User Service: http://localhost:8081"
echo "Notification Service: http://localhost:8082"
echo "Website API: http://localhost:8080"
EOF

chmod +x start-local-backend.sh
./start-local-backend.sh
```

### 4. 启动前端服务

```bash
cd frontend

# 方式一：开发服务器（如果支持）
npm run dev

# 方式二：静态文件服务器
npx http-server dist/ -p 3000 -c-1

# 方式三：使用Python（如果没有Node.js服务器）
cd dist && python3 -m http.server 3000
```

## 🔗 服务连接配置

### 前端API配置

确保前端正确配置API端点：

```javascript
// frontend/src/config/api.js 或类似配置文件
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

### 跨域问题解决

如果遇到CORS问题，可以：

1. **在后端添加CORS头**（推荐）
2. **使用代理服务器**
3. **浏览器禁用安全检查**（仅开发环境）

```bash
# 临时禁用Chrome CORS检查（仅开发用）
open -n -a /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --user-data-dir="/tmp/chrome_dev_test" --disable-web-security
```

## 🧪 API接口测试

### 1. 健康检查

```bash
# 测试各服务是否正常运行
curl -f http://localhost:8080/health || echo "Website API 未响应"
curl -f http://localhost:8081/health || echo "User Service 未响应"  
curl -f http://localhost:8082/health || echo "Notification Service 未响应"
```

### 2. 基础API测试

```bash
# 测试网站API
curl http://localhost:8080/api/info

# 测试用户服务（示例）
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "email": "test@example.com"}'

# 测试通知服务（示例）
curl http://localhost:8082/api/notifications
```

### 3. 端到端流程测试

创建简单的端到端测试脚本：

```bash
#!/bin/bash
# e2e-test.sh

echo "=== 端到端测试 ==="

# 1. 健康检查
echo "1. 健康检查..."
curl -f http://localhost:8080/health && echo "✅ Website API OK" || echo "❌ Website API Failed"
curl -f http://localhost:8081/health && echo "✅ User Service OK" || echo "❌ User Service Failed"
curl -f http://localhost:8082/health && echo "✅ Notification Service OK" || echo "❌ Notification Service Failed"

# 2. 前端访问测试
echo "2. 前端访问测试..."
curl -f http://localhost:3000 && echo "✅ Frontend OK" || echo "❌ Frontend Failed"

# 3. API集成测试
echo "3. API集成测试..."
# 根据实际API添加测试

echo "=== 测试完成 ==="
```

## 🛠️ 调试工具和技巧

### 1. 日志查看

```bash
# 查看服务日志（如果服务输出到文件）
tail -f backend/user-service/logs/app.log
tail -f backend/notification-service/logs/app.log
tail -f backend/website-api/logs/app.log

# 查看Docker容器日志
docker logs dev-mysql
docker logs dev-redis
```

### 2. 进程管理

```bash
# 查看运行的服务进程
ps aux | grep -E "(user-service|notification-service|website-api)"

# 停止所有后端服务
pkill -f user-service
pkill -f notification-service  
pkill -f website-api

# 或使用PID停止
kill $USER_SERVICE_PID $NOTIFICATION_SERVICE_PID $WEBSITE_API_PID
```

### 3. 网络调试

```bash
# 检查端口占用
lsof -i :8080
lsof -i :8081
lsof -i :8082
lsof -i :3000

# 检查网络连接
netstat -an | grep -E "(8080|8081|8082|3000)"
```

## 📊 性能监控

### 简单的性能监控

```bash
# 监控API响应时间
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8080/api/info

# curl-format.txt 内容：
cat > curl-format.txt << 'EOF'
     time_namelookup:  %{time_namelookup}\n
        time_connect:  %{time_connect}\n
     time_appconnect:  %{time_appconnect}\n
    time_pretransfer:  %{time_pretransfer}\n
       time_redirect:  %{time_redirect}\n
  time_starttransfer:  %{time_starttransfer}\n
                     ----------\n
          time_total:  %{time_total}\n
EOF
```

## 🚀 自动化脚本

创建完整的本地开发环境启动脚本：

```bash
#!/bin/bash
# start-local-dev.sh

set -e

echo "=== 启动本地开发环境 ==="

# 1. 检查前置条件
echo "1. 检查前置条件..."
command -v docker >/dev/null 2>&1 || { echo "Docker 未安装"; exit 1; }
[ -d "frontend/dist" ] || { echo "前端未构建"; exit 1; }
[ -f "backend/user-service/bin/user-service" ] || { echo "后端未构建"; exit 1; }

# 2. 启动依赖服务
echo "2. 启动依赖服务..."
docker run -d --name dev-mysql -e MYSQL_ROOT_PASSWORD=password -p 3306:3306 mysql:8.0 2>/dev/null || echo "MySQL已运行"
docker run -d --name dev-redis -p 6379:6379 redis:alpine 2>/dev/null || echo "Redis已运行"

# 3. 等待数据库启动
echo "3. 等待数据库启动..."
sleep 10

# 4. 启动后端服务
echo "4. 启动后端服务..."
./start-local-backend.sh

# 5. 启动前端服务
echo "5. 启动前端服务..."
cd frontend && npx http-server dist/ -p 3000 -c-1 &
cd ..

# 6. 等待服务启动
sleep 5

# 7. 运行健康检查
echo "6. 运行健康检查..."
./e2e-test.sh

echo "=== 本地开发环境启动完成 ==="
echo "前端地址: http://localhost:3000"
echo "API地址: http://localhost:8080"
echo ""
echo "停止环境: ./stop-local-dev.sh"
```

## 🐛 常见问题

### 端口冲突
```bash
# 查找并杀死占用端口的进程
lsof -ti:8080 | xargs kill -9
lsof -ti:3000 | xargs kill -9
```

### 服务启动失败
```bash
# 检查二进制文件权限
chmod +x backend/*/bin/*

# 检查配置文件
cat backend/.env.local

# 检查依赖服务
docker ps
```

### 数据库连接问题
```bash
# 测试数据库连接
docker exec -it dev-mysql mysql -u root -ppassword -e "SHOW DATABASES;"

# 重启数据库
docker restart dev-mysql
```

## ✅ 验证清单

- [ ] 依赖服务（MySQL/Redis）启动成功
- [ ] 所有后端服务正常运行
- [ ] 前端服务正常访问
- [ ] API健康检查通过
- [ ] 前后端通信正常
- [ ] 跨域问题已解决
- [ ] 基础功能测试通过

## 📝 下一步

本地联合调试完成后，继续进行 [前端打包发布](./04-frontend-package-deploy.md)。

## 🔗 相关文档

- [前端编译测试](./01-frontend-build-test.md)
- [后端编译测试](./02-backend-build-test.md)
- [故障排除指南](./troubleshooting.md)