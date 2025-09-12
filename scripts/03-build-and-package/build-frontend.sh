#!/bin/bash

# 前端构建脚本 - 支持灵活的构建选项
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}前端构建工具${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示帮助信息"
    echo "  -c, --clean          构建前清理输出目录"
    echo "  -i, --install        强制重新安装依赖"
    echo "  -d, --dev            开发模式构建"
    echo "  -p, --prod           生产模式构建（默认）"
    echo "  -a, --analyze        分析构建包大小"
    echo "  -s, --serve          构建后启动预览服务器"
    echo "  -v, --verbose        显示详细输出"
    echo "  --skip-install       跳过依赖安装"
    echo "  --output-dir=DIR     指定输出目录（默认: dist）"
    echo "  --base-url=URL       指定基础URL"
    echo ""
    echo "示例:"
    echo "  $0                   # 生产模式构建"
    echo "  $0 --dev             # 开发模式构建"
    echo "  $0 --clean --prod    # 清理后生产构建"
    echo "  $0 --analyze         # 构建并分析包大小"
    echo "  $0 --serve           # 构建后启动预览"
}

# 默认参数
CLEAN=false
INSTALL_DEPS=false
DEV_MODE=false
PROD_MODE=true
ANALYZE=false
SERVE=false
VERBOSE=false
SKIP_INSTALL=false
OUTPUT_DIR="dist"
BASE_URL=""

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
        -i|--install)
            INSTALL_DEPS=true
            shift
            ;;
        -d|--dev)
            DEV_MODE=true
            PROD_MODE=false
            shift
            ;;
        -p|--prod)
            PROD_MODE=true
            DEV_MODE=false
            shift
            ;;
        -a|--analyze)
            ANALYZE=true
            shift
            ;;
        -s|--serve)
            SERVE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-install)
            SKIP_INSTALL=true
            shift
            ;;
        --output-dir=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --base-url=*)
            BASE_URL="${1#*=}"
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

echo -e "${BLUE}🎨 前端构建工具${NC}"
if [ "$DEV_MODE" = true ]; then
    echo "构建模式: 开发模式"
else
    echo "构建模式: 生产模式"
fi
echo "输出目录: $OUTPUT_DIR"
if [ -n "$BASE_URL" ]; then
    echo "基础URL: $BASE_URL"
fi
echo ""

# 检查Node.js环境
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js未安装${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm未安装${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    echo "Node.js版本: $(node --version)"
    echo "npm版本: $(npm --version)"
    echo ""
fi

# 检查前端目录
if [ ! -d "frontend" ]; then
    echo -e "${RED}❌ frontend目录不存在${NC}"
    exit 1
fi

cd frontend

# 检查package.json
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ package.json文件不存在${NC}"
    exit 1
fi

# 清理输出目录
if [ "$CLEAN" = true ]; then
    echo -e "${BLUE}🧹 清理输出目录...${NC}"
    rm -rf "$OUTPUT_DIR"
    rm -rf node_modules/.cache 2>/dev/null || true
fi

# 安装依赖
if [ "$SKIP_INSTALL" = false ]; then
    if [ "$INSTALL_DEPS" = true ] || [ ! -d "node_modules" ]; then
        echo -e "${BLUE}📦 安装依赖...${NC}"
        if [ "$INSTALL_DEPS" = true ]; then
            rm -rf node_modules package-lock.json 2>/dev/null || true
        fi
        
        if [ "$VERBOSE" = true ]; then
            npm install --verbose
        else
            npm install
        fi
    else
        echo -e "${BLUE}📦 检查依赖...${NC}"
        npm ci --silent
    fi
fi

# 设置环境变量
export NODE_ENV=$([ "$PROD_MODE" = true ] && echo "production" || echo "development")

if [ -n "$BASE_URL" ]; then
    export VITE_BASE_URL="$BASE_URL"
    export PUBLIC_URL="$BASE_URL"
fi

# 构建应用
echo -e "${BLUE}🔨 构建前端应用...${NC}"

# 确定构建命令
BUILD_CMD="npm run build"
if [ "$DEV_MODE" = true ]; then
    BUILD_CMD="npm run build:dev"
fi

# 如果有分析需求，尝试使用分析命令
if [ "$ANALYZE" = true ]; then
    if npm run | grep -q "build:analyze"; then
        BUILD_CMD="npm run build:analyze"
    else
        echo -e "${YELLOW}⚠️  未找到 build:analyze 脚本，使用普通构建${NC}"
    fi
fi

# 执行构建
if [ "$VERBOSE" = true ]; then
    $BUILD_CMD --verbose
else
    $BUILD_CMD
fi

# 检查构建结果
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${GREEN}✅ 前端构建成功${NC}"
    echo "📁 输出目录: frontend/$OUTPUT_DIR"
    
    # 计算构建大小
    total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)
    echo "📊 总大小: $total_size"
    
    # 显示主要文件
    echo ""
    echo -e "${BLUE}📋 主要文件:${NC}"
    
    # HTML文件
    if find "$OUTPUT_DIR" -name "*.html" | head -5 | grep -q .; then
        echo "  HTML文件:"
        find "$OUTPUT_DIR" -name "*.html" | head -5 | while read file; do
            size=$(du -sh "$file" | cut -f1)
            echo "    $(basename "$file") ($size)"
        done
    fi
    
    # CSS文件
    if find "$OUTPUT_DIR" -name "*.css" | head -5 | grep -q .; then
        echo "  CSS文件:"
        find "$OUTPUT_DIR" -name "*.css" | head -5 | while read file; do
            size=$(du -sh "$file" | cut -f1)
            echo "    $(basename "$file") ($size)"
        done
    fi
    
    # JS文件
    if find "$OUTPUT_DIR" -name "*.js" | head -5 | grep -q .; then
        echo "  JS文件:"
        find "$OUTPUT_DIR" -name "*.js" | head -5 | while read file; do
            size=$(du -sh "$file" | cut -f1)
            echo "    $(basename "$file") ($size)"
        done
    fi
    
    # 文件统计
    html_count=$(find "$OUTPUT_DIR" -name "*.html" | wc -l)
    css_count=$(find "$OUTPUT_DIR" -name "*.css" | wc -l)
    js_count=$(find "$OUTPUT_DIR" -name "*.js" | wc -l)
    
    echo ""
    echo -e "${BLUE}📊 文件统计:${NC}"
    echo "  HTML: $html_count 个文件"
    echo "  CSS: $css_count 个文件"
    echo "  JS: $js_count 个文件"
    
    # 启动预览服务器
    if [ "$SERVE" = true ]; then
        echo ""
        echo -e "${BLUE}🌐 启动预览服务器...${NC}"
        
        # 尝试不同的预览命令
        if npm run | grep -q "preview"; then
            echo "使用 npm run preview"
            npm run preview
        elif command -v python3 &> /dev/null; then
            echo "使用 Python HTTP 服务器"
            cd "$OUTPUT_DIR"
            echo "访问地址: http://localhost:8000"
            python3 -m http.server 8000
        elif command -v python &> /dev/null; then
            echo "使用 Python HTTP 服务器"
            cd "$OUTPUT_DIR"
            echo "访问地址: http://localhost:8000"
            python -m SimpleHTTPServer 8000
        else
            echo -e "${YELLOW}⚠️  无法启动预览服务器，请手动预览构建结果${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}🎉 前端构建完成！${NC}"
    
    # 下一步提示
    echo ""
    echo -e "${BLUE}💡 下一步:${NC}"
    if [ "$DEV_MODE" = true ]; then
        echo "  - 生产构建: $0 --prod"
        echo "  - 预览构建: $0 --serve"
    else
        echo "  - 构建Docker镜像: scripts/03-build-and-package/build-docker-images.sh"
        echo "  - 部署到测试环境: scripts/04-test-deployment/deploy-to-test.sh"
    fi
else
    echo -e "${RED}❌ 前端构建失败${NC}"
    exit 1
fi

cd ..