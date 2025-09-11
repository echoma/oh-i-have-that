#!/bin/bash

# 后端构建脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}⚙️ 后端构建工具${NC}"
echo ""

# 检查Go环境
if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ Go未安装${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

echo "Go版本: $(go version)"
echo ""

# 应用列表
apps=("website-api" "user-service" "notification-service")

# 构建每个应用
for app in "${apps[@]}"; do
    echo -e "${BLUE}构建应用: $app${NC}"
    
    if [ ! -d "backend/$app" ]; then
        echo -e "${RED}❌ 目录 backend/$app 不存在${NC}"
        continue
    fi
    
    cd "backend/$app"
    
    # 检查go.mod文件
    if [ ! -f "go.mod" ]; then
        echo -e "${RED}❌ go.mod 文件不存在${NC}"
        cd "../.."
        continue
    fi
    
    # 下载依赖
    echo "  📦 下载依赖..."
    go mod download
    
    # 构建应用
    echo "  🔨 编译应用..."
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/$app main.go
    
    if [ -f "bin/$app" ]; then
        echo -e "  ${GREEN}✅ $app 构建成功${NC}"
        echo "  📁 输出: backend/$app/bin/$app"
        echo "  📊 大小: $(du -sh bin/$app | cut -f1)"
    else
        echo -e "  ${RED}❌ $app 构建失败${NC}"
    fi
    
    echo ""
    cd "../.."
done

echo -e "${GREEN}🎉 后端构建完成！${NC}"