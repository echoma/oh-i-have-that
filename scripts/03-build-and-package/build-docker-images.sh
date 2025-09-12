#!/bin/bash

# Docker镜像构建脚本 - 支持灵活的构建选项
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Docker镜像构建工具${NC}"
    echo ""
    echo "用法: $0 [选项] [服务名...]"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示帮助信息"
    echo "  -t, --tag=TAG        指定镜像标签（默认: latest）"
    echo "  -r, --registry=REG   指定镜像仓库前缀"
    echo "  -p, --push           构建后推送到仓库"
    echo "  -c, --clean          构建前清理旧镜像"
    echo "  -v, --verbose        显示详细输出"
    echo "  --no-cache           不使用构建缓存"
    echo "  --platform=PLATFORM  指定目标平台（默认: linux/amd64）"
    echo "  --build-arg=ARG      传递构建参数"
    echo ""
    echo "服务名（可选，默认构建所有）:"
    echo "  website-api          网站API服务"
    echo "  user-service         用户服务"
    echo "  notification-service 通知服务"
    echo "  frontend             前端应用"
    echo ""
    echo "示例:"
    echo "  $0                                    # 构建所有镜像"
    echo "  $0 website-api user-service           # 只构建指定服务"
    echo "  $0 --tag=v1.0.0 --push               # 构建并推送v1.0.0版本"
    echo "  $0 --registry=myregistry.com/myapp    # 使用自定义仓库"
    echo "  $0 --no-cache --verbose               # 无缓存详细构建"
}

# 默认参数
TAG="latest"
REGISTRY=""
PUSH=false
CLEAN=false
VERBOSE=false
NO_CACHE=false
PLATFORM="linux/amd64"
BUILD_ARGS=()
SERVICES=()

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        --tag=*)
            TAG="${1#*=}"
            shift
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        --registry=*)
            REGISTRY="${1#*=}"
            shift
            ;;
        -p|--push)
            PUSH=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --platform=*)
            PLATFORM="${1#*=}"
            shift
            ;;
        --build-arg=*)
            BUILD_ARGS+=("${1#*=}")
            shift
            ;;
        -*)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            SERVICES+=("$1")
            shift
            ;;
    esac
done

# 如果没有指定服务，构建所有服务
if [ ${#SERVICES[@]} -eq 0 ]; then
    SERVICES=("website-api" "user-service" "notification-service" "frontend")
fi

echo -e "${BLUE}🐳 Docker镜像构建工具${NC}"
echo "标签: $TAG"
echo "平台: $PLATFORM"
if [ -n "$REGISTRY" ]; then
    echo "仓库: $REGISTRY"
fi
echo "服务: ${SERVICES[*]}"
echo ""

# 检查Docker环境
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    echo "Docker版本: $(docker --version)"
    echo ""
fi

# 清理旧镜像
if [ "$CLEAN" = true ]; then
    echo -e "${BLUE}🧹 清理旧镜像...${NC}"
    for service in "${SERVICES[@]}"; do
        image_name="$service"
        if [ -n "$REGISTRY" ]; then
            image_name="$REGISTRY/$service"
        fi
        
        # 删除指定标签的镜像
        if docker images -q "$image_name:$TAG" 2>/dev/null | grep -q .; then
            echo "删除镜像: $image_name:$TAG"
            docker rmi "$image_name:$TAG" 2>/dev/null || true
        fi
        
        # 删除dangling镜像
        if docker images -f "dangling=true" -q | grep -q .; then
            docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
        fi
    done
    echo ""
fi

# 构建函数
build_service() {
    local service=$1
    local service_dir=""
    local dockerfile=""
    
    echo -e "${BLUE}🔨 构建 $service 镜像...${NC}"
    
    # 确定服务目录和Dockerfile
    case $service in
        "website-api"|"user-service"|"notification-service")
            service_dir="backend/$service"
            dockerfile="$service_dir/Dockerfile"
            ;;
        "frontend")
            service_dir="frontend"
            dockerfile="$service_dir/Dockerfile"
            ;;
        *)
            echo -e "${RED}❌ 未知服务: $service${NC}"
            return 1
            ;;
    esac
    
    # 检查服务目录
    if [ ! -d "$service_dir" ]; then
        echo -e "${RED}❌ 服务目录不存在: $service_dir${NC}"
        return 1
    fi
    
    # 检查或创建Dockerfile
    if [ ! -f "$dockerfile" ]; then
        echo -e "${YELLOW}📝 创建 $service Dockerfile...${NC}"
        create_dockerfile "$service" "$dockerfile"
    fi
    
    # 构建镜像名称
    local image_name="$service"
    if [ -n "$REGISTRY" ]; then
        image_name="$REGISTRY/$service"
    fi
    
    # 准备构建参数
    local build_cmd="docker build"
    
    # 添加平台参数
    build_cmd="$build_cmd --platform $PLATFORM"
    
    # 添加标签
    build_cmd="$build_cmd -t $image_name:$TAG"
    
    # 添加no-cache参数
    if [ "$NO_CACHE" = true ]; then
        build_cmd="$build_cmd --no-cache"
    fi
    
    # 添加构建参数
    for arg in "${BUILD_ARGS[@]}"; do
        build_cmd="$build_cmd --build-arg $arg"
    fi
    
    # 添加Dockerfile路径
    build_cmd="$build_cmd -f $dockerfile"
    
    # 添加构建上下文
    build_cmd="$build_cmd $service_dir"
    
    # 执行构建
    echo "执行命令: $build_cmd"
    if [ "$VERBOSE" = true ]; then
        eval "$build_cmd"
    else
        eval "$build_cmd" > /dev/null
    fi
    
    # 检查构建结果
    if docker images -q "$image_name:$TAG" 2>/dev/null | grep -q .; then
        echo -e "${GREEN}✅ $service 镜像构建成功${NC}"
        
        # 显示镜像信息
        local image_size=$(docker images --format "table {{.Size}}" "$image_name:$TAG" | tail -n 1)
        echo "镜像大小: $image_size"
        
        # 推送镜像
        if [ "$PUSH" = true ]; then
            echo -e "${BLUE}📤 推送 $service 镜像...${NC}"
            if docker push "$image_name:$TAG"; then
                echo -e "${GREEN}✅ $service 镜像推送成功${NC}"
            else
                echo -e "${RED}❌ $service 镜像推送失败${NC}"
                return 1
            fi
        fi
        
        return 0
    else
        echo -e "${RED}❌ $service 镜像构建失败${NC}"
        return 1
    fi
}

# 创建Dockerfile函数
create_dockerfile() {
    local service=$1
    local dockerfile=$2
    
    case $service in
        "website-api"|"user-service"|"notification-service")
            cat > "$dockerfile" << 'EOF'
# 多阶段构建 - 构建阶段
FROM golang:1.21-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要工具
RUN apk add --no-cache git ca-certificates tzdata

# 复制go mod文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 交叉编译 - 针对腾讯云SCF x86-64架构
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o main .

# 运行阶段
FROM alpine:latest

# 安装ca证书和时区数据
RUN apk --no-cache add ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非root用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/main .

# 更改文件所有者
RUN chown -R appuser:appgroup /app

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# 启动应用
CMD ["./main"]
EOF
            ;;
        "frontend")
            cat > "$dockerfile" << 'EOF'
# 多阶段构建 - 构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production

# 复制源代码
COPY . .

# 构建应用
RUN npm run build

# 运行阶段 - 使用nginx提供静态文件服务
FROM nginx:alpine

# 复制构建结果到nginx目录
COPY --from=builder /app/dist /usr/share/nginx/html

# 复制nginx配置（如果存在）
COPY nginx.conf /etc/nginx/nginx.conf 2>/dev/null || true

# 暴露端口
EXPOSE 80

# 启动nginx
CMD ["nginx", "-g", "daemon off;"]
EOF
            ;;
    esac
}

# 构建所有服务
failed_services=()
successful_services=()

for service in "${SERVICES[@]}"; do
    if build_service "$service"; then
        successful_services+=("$service")
    else
        failed_services+=("$service")
    fi
    echo ""
done

# 显示构建结果
echo -e "${BLUE}📊 构建结果:${NC}"
echo ""

if [ ${#successful_services[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ 成功构建的服务:${NC}"
    for service in "${successful_services[@]}"; do
        image_name="$service"
        if [ -n "$REGISTRY" ]; then
            image_name="$REGISTRY/$service"
        fi
        echo "  - $service ($image_name:$TAG)"
    done
    echo ""
fi

if [ ${#failed_services[@]} -gt 0 ]; then
    echo -e "${RED}❌ 构建失败的服务:${NC}"
    for service in "${failed_services[@]}"; do
        echo "  - $service"
    done
    echo ""
fi

# 显示镜像列表
echo -e "${BLUE}📋 构建的镜像:${NC}"
for service in "${successful_services[@]}"; do
    image_name="$service"
    if [ -n "$REGISTRY" ]; then
        image_name="$REGISTRY/$service"
    fi
    if docker images "$image_name:$TAG" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | tail -n +2; then
        :
    fi
done

# 下一步提示
if [ ${#successful_services[@]} -gt 0 ]; then
    echo ""
    echo -e "${BLUE}💡 下一步:${NC}"
    if [ "$PUSH" = false ]; then
        echo "  - 推送镜像: $0 --push --tag=$TAG"
    fi
    echo "  - 部署到测试环境: scripts/04-test-deployment/deploy-to-test.sh"
    echo "  - 查看镜像: docker images"
fi

# 退出状态
if [ ${#failed_services[@]} -gt 0 ]; then
    exit 1
else
    echo -e "${GREEN}🎉 所有镜像构建完成！${NC}"
    exit 0
fi