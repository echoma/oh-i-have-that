#!/bin/bash

# 后端构建脚本 - 支持灵活的构建选项
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}后端构建工具${NC}"
    echo ""
    echo "用法: $0 [选项] [服务名...]"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示帮助信息"
    echo "  -a, --all            构建所有服务（默认）"
    echo "  -c, --clean          构建前清理输出目录"
    echo "  -t, --test           构建后运行测试"
    echo "  -v, --verbose        显示详细输出"
    echo "  --skip-deps          跳过依赖下载"
    echo "  --local              本地架构构建（用于本地测试）"
    echo "  --target=ARCH        指定目标架构（默认: linux/amd64）"
    echo ""
    echo "服务名:"
    echo "  website-api          网站API服务"
    echo "  user-service         用户服务"
    echo "  notification-service 通知服务"
    echo ""
    echo "示例:"
    echo "  $0                           # 构建所有服务"
    echo "  $0 website-api               # 只构建website-api"
    echo "  $0 website-api user-service  # 构建指定的多个服务"
    echo "  $0 --clean --all             # 清理后构建所有服务"
    echo "  $0 --local website-api       # 本地架构构建（用于本地测试）"
    echo "  $0 --target=darwin/arm64 -a  # 指定目标架构"
}

# 默认参数
BUILD_ALL=true
CLEAN=false
RUN_TESTS=false
VERBOSE=false
SKIP_DEPS=false
LOCAL_BUILD=false
TARGET_OS="linux"
TARGET_ARCH="amd64"
SERVICES=()

# 所有可用服务
ALL_SERVICES=("website-api" "user-service" "notification-service")

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            BUILD_ALL=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -t|--test)
            RUN_TESTS=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --local)
            LOCAL_BUILD=true
            TARGET_OS=$(go env GOOS)
            TARGET_ARCH=$(go env GOARCH)
            shift
            ;;
        --target=*)
            TARGET="${1#*=}"
            if [[ "$TARGET" == *"/"* ]]; then
                TARGET_OS="${TARGET%/*}"
                TARGET_ARCH="${TARGET#*/}"
            else
                echo -e "${RED}❌ 目标架构格式错误，应为: OS/ARCH (如: linux/amd64)${NC}"
                exit 1
            fi
            shift
            ;;
        -*)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            # 服务名
            if [[ " ${ALL_SERVICES[@]} " =~ " $1 " ]]; then
                SERVICES+=("$1")
                BUILD_ALL=false
            else
                echo -e "${RED}❌ 未知服务: $1${NC}"
                echo "可用服务: ${ALL_SERVICES[*]}"
                exit 1
            fi
            shift
            ;;
    esac
done

# 如果没有指定服务且不是构建全部，显示帮助
if [ ${#SERVICES[@]} -eq 0 ] && [ "$BUILD_ALL" = false ]; then
    BUILD_ALL=true
fi

# 确定要构建的服务列表
if [ "$BUILD_ALL" = true ]; then
    SERVICES=("${ALL_SERVICES[@]}")
fi

echo -e "${BLUE}⚙️ 后端构建工具${NC}"
echo "目标架构: $TARGET_OS/$TARGET_ARCH"
if [ "$LOCAL_BUILD" = true ]; then
    echo -e "${YELLOW}⚠️  本地构建模式（用于本地测试）${NC}"
else
    echo -e "${GREEN}☁️  云端部署模式（腾讯云SCF兼容）${NC}"
fi
echo "构建服务: ${SERVICES[*]}"
echo ""

# 检查Go环境
if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ Go未安装${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    echo "Go版本: $(go version)"
    echo "GOPATH: $(go env GOPATH)"
    echo "GOOS: $(go env GOOS)"
    echo "GOARCH: $(go env GOARCH)"
    echo ""
fi

# 构建函数
build_service() {
    local service=$1
    echo -e "${BLUE}构建服务: $service${NC}"
    
    if [ ! -d "backend/$service" ]; then
        echo -e "${RED}❌ 目录 backend/$service 不存在${NC}"
        return 1
    fi
    
    cd "backend/$service"
    
    # 检查go.mod文件
    if [ ! -f "go.mod" ]; then
        echo -e "${RED}❌ go.mod 文件不存在${NC}"
        cd "../.."
        return 1
    fi
    
    # 创建输出目录
    mkdir -p bin
    
    # 清理输出目录
    if [ "$CLEAN" = true ]; then
        echo "  🧹 清理输出目录..."
        rm -f bin/*
    fi
    
    # 下载依赖
    if [ "$SKIP_DEPS" = false ]; then
        echo "  📦 下载依赖..."
        if [ "$VERBOSE" = true ]; then
            go mod download -x
        else
            go mod download
        fi
        go mod tidy
    fi
    
    # 构建应用
    echo "  🔨 编译应用（目标: $TARGET_OS/$TARGET_ARCH）..."
    
    # 构建参数
    local build_flags="-ldflags=-w -s"
    if [ "$VERBOSE" = true ]; then
        build_flags="$build_flags -v"
    fi
    
    # 执行构建
    if CGO_ENABLED=0 GOOS=$TARGET_OS GOARCH=$TARGET_ARCH go build $build_flags -o bin/$service main.go; then
        echo -e "  ${GREEN}✅ $service 构建成功${NC}"
        echo "  📁 输出: backend/$service/bin/$service"
        echo "  📊 大小: $(du -sh bin/$service | cut -f1)"
        
        # 验证架构
        if command -v file &> /dev/null; then
            file_info=$(file bin/$service)
            echo "  🏗️  架构: $file_info"
            
            # 架构验证
            if [ "$TARGET_ARCH" = "amd64" ] && echo "$file_info" | grep -q "x86-64"; then
                echo -e "  ${GREEN}✅ 架构验证通过: x86-64${NC}"
            elif [ "$TARGET_ARCH" = "arm64" ] && echo "$file_info" | grep -q "aarch64"; then
                echo -e "  ${GREEN}✅ 架构验证通过: aarch64${NC}"
            else
                echo -e "  ${YELLOW}⚠️  架构信息: $file_info${NC}"
            fi
        fi
        
        # 运行测试
        if [ "$RUN_TESTS" = true ]; then
            echo "  🧪 运行测试..."
            if go test ./...; then
                echo -e "  ${GREEN}✅ 测试通过${NC}"
            else
                echo -e "  ${YELLOW}⚠️  测试失败${NC}"
            fi
        fi
        
        cd "../.."
        return 0
    else
        echo -e "  ${RED}❌ $service 构建失败${NC}"
        cd "../.."
        return 1
    fi
}

# 构建所有指定的服务
success_count=0
total_count=${#SERVICES[@]}

for service in "${SERVICES[@]}"; do
    if build_service "$service"; then
        ((success_count++))
    fi
    echo ""
done

# 构建总结
echo -e "${BLUE}📊 构建总结:${NC}"
echo "成功: $success_count/$total_count"

if [ $success_count -eq $total_count ]; then
    echo -e "${GREEN}🎉 所有服务构建完成！${NC}"
    
    # 显示构建结果
    echo ""
    echo -e "${BLUE}📋 构建结果:${NC}"
    for service in "${SERVICES[@]}"; do
        if [ -f "backend/$service/bin/$service" ]; then
            size=$(du -sh "backend/$service/bin/$service" | cut -f1)
            echo -e "${GREEN}✅ $service${NC} - $size"
        else
            echo -e "${RED}❌ $service${NC}"
        fi
    done
    
    # 下一步提示
    echo ""
    echo -e "${BLUE}💡 下一步:${NC}"
    if [ "$LOCAL_BUILD" = true ]; then
        echo "  - 本地测试: cd backend/SERVICE_NAME && ./bin/SERVICE_NAME"
        echo "  - 云端构建: $0 --all"
    else
        echo "  - 构建Docker镜像: scripts/03-build-and-package/build-docker-images.sh"
        echo "  - 部署到测试环境: scripts/04-test-deployment/deploy-to-test.sh"
    fi
else
    echo -e "${YELLOW}⚠️  部分服务构建失败${NC}"
    exit 1
fi