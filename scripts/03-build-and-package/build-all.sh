#!/bin/bash

# 完整构建脚本 - 一键构建所有组件
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}完整构建工具${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示帮助信息"
    echo "  -c, --clean          构建前清理所有输出"
    echo "  -v, --verbose        显示详细输出"
    echo "  -s, --skip-frontend  跳过前端构建"
    echo "  -b, --skip-backend   跳过后端构建"
    echo "  -d, --skip-docker    跳过Docker镜像构建"
    echo "  -p, --push           构建Docker镜像后推送"
    echo "  -t, --tag=TAG        指定镜像标签（默认: latest）"
    echo "  --registry=REG       指定镜像仓库前缀"
    echo ""
    echo "示例:"
    echo "  $0                   # 完整构建（前端+后端+Docker）"
    echo "  $0 --clean           # 清理后完整构建"
    echo "  $0 --skip-frontend   # 只构建后端和Docker"
    echo "  $0 --tag=v1.0.0 --push  # 构建并推送v1.0.0版本"
}

# 默认参数
CLEAN=false
VERBOSE=false
SKIP_FRONTEND=false
SKIP_BACKEND=false
SKIP_DOCKER=false
PUSH=false
TAG="latest"
REGISTRY=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--skip-frontend)
            SKIP_FRONTEND=true
            shift
            ;;
        -b|--skip-backend)
            SKIP_BACKEND=true
            shift
            ;;
        -d|--skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        -p|--push)
            PUSH=true
            shift
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        --tag=*)
            TAG="${1#*=}"
            shift
            ;;
        --registry=*)
            REGISTRY="${1#*=}"
            shift
            ;;
        -*)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            echo -e "${RED}❌ 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 完整构建工具${NC}"
echo "构建配置:"
echo "  - 前端构建: $([ "$SKIP_FRONTEND" = true ] && echo "跳过" || echo "启用")"
echo "  - 后端构建: $([ "$SKIP_BACKEND" = true ] && echo "跳过" || echo "启用")"
echo "  - Docker构建: $([ "$SKIP_DOCKER" = true ] && echo "跳过" || echo "启用")"
echo "  - 镜像标签: $TAG"
if [ -n "$REGISTRY" ]; then
    echo "  - 镜像仓库: $REGISTRY"
fi
echo "  - 推送镜像: $([ "$PUSH" = true ] && echo "是" || echo "否")"
echo "  - 清理构建: $([ "$CLEAN" = true ] && echo "是" || echo "否")"
echo ""

# 记录开始时间
start_time=$(date +%s)

# 构建步骤计数
total_steps=0
current_step=0

# 计算总步骤数
[ "$SKIP_FRONTEND" = false ] && ((total_steps++))
[ "$SKIP_BACKEND" = false ] && ((total_steps++))
[ "$SKIP_DOCKER" = false ] && ((total_steps++))

if [ $total_steps -eq 0 ]; then
    echo -e "${YELLOW}⚠️  所有构建步骤都被跳过${NC}"
    exit 0
fi

# 构建前端
if [ "$SKIP_FRONTEND" = false ]; then
    ((current_step++))
    echo -e "${BLUE}📦 步骤 $current_step/$total_steps: 构建前端应用${NC}"
    
    frontend_args=""
    [ "$CLEAN" = true ] && frontend_args="$frontend_args --clean"
    [ "$VERBOSE" = true ] && frontend_args="$frontend_args --verbose"
    
    if ./scripts/03-build-and-package/build-frontend.sh $frontend_args; then
        echo -e "${GREEN}✅ 前端构建成功${NC}"
    else
        echo -e "${RED}❌ 前端构建失败${NC}"
        exit 1
    fi
    echo ""
fi

# 构建后端
if [ "$SKIP_BACKEND" = false ]; then
    ((current_step++))
    echo -e "${BLUE}⚙️  步骤 $current_step/$total_steps: 构建后端服务${NC}"
    
    backend_args=""
    [ "$CLEAN" = true ] && backend_args="$backend_args --clean"
    [ "$VERBOSE" = true ] && backend_args="$backend_args --verbose"
    
    if ./scripts/03-build-and-package/build-backend.sh $backend_args; then
        echo -e "${GREEN}✅ 后端构建成功${NC}"
    else
        echo -e "${RED}❌ 后端构建失败${NC}"
        exit 1
    fi
    echo ""
fi

# 构建Docker镜像
if [ "$SKIP_DOCKER" = false ]; then
    ((current_step++))
    echo -e "${BLUE}🐳 步骤 $current_step/$total_steps: 构建Docker镜像${NC}"
    
    docker_args="--tag=$TAG"
    [ "$CLEAN" = true ] && docker_args="$docker_args --clean"
    [ "$VERBOSE" = true ] && docker_args="$docker_args --verbose"
    [ "$PUSH" = true ] && docker_args="$docker_args --push"
    [ -n "$REGISTRY" ] && docker_args="$docker_args --registry=$REGISTRY"
    
    if ./scripts/03-build-and-package/build-docker-images.sh $docker_args; then
        echo -e "${GREEN}✅ Docker镜像构建成功${NC}"
    else
        echo -e "${RED}❌ Docker镜像构建失败${NC}"
        exit 1
    fi
    echo ""
fi

# 计算总耗时
end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))

# 显示构建总结
echo -e "${BLUE}📊 构建总结${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 前端构建结果
if [ "$SKIP_FRONTEND" = false ]; then
    if [ -d "frontend/dist" ]; then
        frontend_size=$(du -sh frontend/dist 2>/dev/null | cut -f1 || echo "未知")
        frontend_files=$(find frontend/dist -type f 2>/dev/null | wc -l || echo "0")
        echo "🎨 前端: ✅ 成功 ($frontend_size, $frontend_files 个文件)"
    else
        echo "🎨 前端: ❌ 失败"
    fi
fi

# 后端构建结果
if [ "$SKIP_BACKEND" = false ]; then
    echo "⚙️  后端服务:"
    for service in website-api user-service notification-service; do
        if [ -f "backend/$service/bin/$service" ]; then
            service_size=$(du -sh "backend/$service/bin/$service" 2>/dev/null | cut -f1 || echo "未知")
            echo "   - $service: ✅ 成功 ($service_size)"
        else
            echo "   - $service: ❌ 失败"
        fi
    done
fi

# Docker镜像结果
if [ "$SKIP_DOCKER" = false ]; then
    echo "🐳 Docker镜像:"
    for service in website-api user-service notification-service frontend; do
        image_name="$service"
        if [ -n "$REGISTRY" ]; then
            image_name="$REGISTRY/$service"
        fi
        
        if docker images -q "$image_name:$TAG" 2>/dev/null | grep -q .; then
            image_size=$(docker images --format "{{.Size}}" "$image_name:$TAG" 2>/dev/null || echo "未知")
            echo "   - $service: ✅ 成功 ($image_size)"
        else
            echo "   - $service: ❌ 失败"
        fi
    done
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏱️  总耗时: ${minutes}分${seconds}秒"
echo ""

# 下一步提示
echo -e "${BLUE}💡 下一步操作${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$SKIP_DOCKER" = false ] && [ "$PUSH" = false ]; then
    echo "📤 推送镜像到仓库:"
    echo "   $0 --push --tag=$TAG"
    if [ -n "$REGISTRY" ]; then
        echo "   # 或指定仓库: $0 --push --tag=$TAG --registry=$REGISTRY"
    fi
    echo ""
fi

echo "🧪 部署到测试环境:"
echo "   ./scripts/04-test-deployment/deploy-to-test.sh"
echo ""

echo "🚀 部署到生产环境:"
echo "   ./scripts/05-production-deployment/deploy-to-prod.sh"
echo ""

echo "📋 查看构建结果:"
if [ "$SKIP_FRONTEND" = false ]; then
    echo "   ls -la frontend/dist/"
fi
if [ "$SKIP_BACKEND" = false ]; then
    echo "   ls -la backend/*/bin/"
fi
if [ "$SKIP_DOCKER" = false ]; then
    echo "   docker images | grep -E '(website-api|user-service|notification-service|frontend)'"
fi

echo ""
echo -e "${GREEN}🎉 构建完成！${NC}"