#!/bin/bash

# Docker镜像构建脚本
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
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --registry=URL    指定镜像仓库地址"
    echo "  --tag=TAG         指定镜像标签 (默认: latest)"
    echo "  --push            构建后推送到仓库"
    echo "  --no-cache        不使用缓存构建"
    echo ""
    echo "示例:"
    echo "  $0                                    # 构建所有镜像"
    echo "  $0 --tag=v1.0.0                     # 指定标签"
    echo "  $0 --registry=ccr.ccs.tencentyun.com --push  # 推送到腾讯云"
}

# 默认参数
REGISTRY=""
TAG="latest"
PUSH=false
NO_CACHE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --registry=*)
            REGISTRY="${1#*=}"
            shift
            ;;
        --tag=*)
            TAG="${1#*=}"
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🐳 Docker镜像构建工具${NC}"
echo "镜像仓库: ${REGISTRY:-"本地"}"
echo "镜像标签: $TAG"
echo "推送镜像: $PUSH"
echo "使用缓存: $(!$NO_CACHE && echo "是" || echo "否")"
echo ""

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

# 检查Docker服务
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker服务未运行${NC}"
    echo "请启动Docker服务"
    exit 1
fi

echo "Docker版本: $(docker --version)"
echo ""

# 应用列表
apps=("website-api" "user-service" "notification-service")

# 构建镜像函数
build_image() {
    local app=$1
    local image_name=""
    
    if [ -n "$REGISTRY" ]; then
        image_name="$REGISTRY/oh-i-have-that-$app:$TAG"
    else
        image_name="oh-i-have-that-$app:$TAG"
    fi
    
    echo -e "${BLUE}构建镜像: $app${NC}"
    echo "镜像名称: $image_name"
    
    if [ ! -d "backend/$app" ]; then
        echo -e "${RED}❌ 目录 backend/$app 不存在${NC}"
        return 1
    fi
    
    cd "backend/$app"
    
    # 检查Dockerfile
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}❌ Dockerfile 不存在${NC}"
        cd "../.."
        return 1
    fi
    
    # 构建参数
    local build_args="--tag $image_name"
    if $NO_CACHE; then
        build_args="$build_args --no-cache"
    fi
    
    # 构建镜像
    echo "  🔨 构建镜像..."
    if docker build $build_args .; then
        echo -e "  ${GREEN}✅ 镜像构建成功${NC}"
        
        # 显示镜像信息
        local image_size=$(docker images --format "table {{.Size}}" $image_name | tail -1)
        echo "  📊 镜像大小: $image_size"
        
        # 推送镜像
        if $PUSH && [ -n "$REGISTRY" ]; then
            echo "  📤 推送镜像..."
            if docker push $image_name; then
                echo -e "  ${GREEN}✅ 镜像推送成功${NC}"
            else
                echo -e "  ${RED}❌ 镜像推送失败${NC}"
            fi
        fi
    else
        echo -e "  ${RED}❌ 镜像构建失败${NC}"
        cd "../.."
        return 1
    fi
    
    cd "../.."
    echo ""
}

# 构建所有镜像
echo -e "${YELLOW}开始构建Docker镜像...${NC}"
echo ""

success_count=0
total_count=${#apps[@]}

for app in "${apps[@]}"; do
    if build_image $app; then
        ((success_count++))
    fi
done

echo -e "${BLUE}📊 构建统计:${NC}"
echo "成功: $success_count/$total_count"

if [ $success_count -eq $total_count ]; then
    echo -e "${GREEN}🎉 所有镜像构建完成！${NC}"
else
    echo -e "${YELLOW}⚠️  部分镜像构建失败${NC}"
fi

echo ""
echo -e "${BLUE}📋 构建的镜像:${NC}"
for app in "${apps[@]}"; do
    local image_name=""
    if [ -n "$REGISTRY" ]; then
        image_name="$REGISTRY/oh-i-have-that-$app:$TAG"
    else
        image_name="oh-i-have-that-$app:$TAG"
    fi
    
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$image_name"; then
        echo -e "${GREEN}✅ $image_name${NC}"
    else
        echo -e "${RED}❌ $image_name${NC}"
    fi
done

echo ""
echo -e "${BLUE}💡 下一步:${NC}"
if $PUSH && [ -n "$REGISTRY" ]; then
    echo "  - 镜像已推送到仓库，可以开始部署"
else
    echo "  - 推送镜像: $0 --registry=your-registry --push"
    echo "  - 部署应用: scripts/04-test-deployment/deploy-to-test.sh"
fi