#!/bin/bash

# Go依赖下载脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Go依赖下载工具${NC}"
echo ""

# 配置Go代理
echo -e "${YELLOW}📡 配置Go代理...${NC}"
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=sum.golang.google.cn
export GO111MODULE=on

echo "GOPROXY: $GOPROXY"
echo "GOSUMDB: $GOSUMDB"
echo ""

# 检查Go环境
echo -e "${YELLOW}🔍 检查Go环境...${NC}"
if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ Go未安装或不在PATH中${NC}"
    exit 1
fi

GO_VERSION=$(go version)
echo "Go版本: $GO_VERSION"
echo ""

# 应用列表
apps=("website-api" "user-service" "notification-service")

# 下载依赖
echo -e "${YELLOW}📦 开始下载依赖...${NC}"
echo ""

for app in "${apps[@]}"; do
    echo -e "${BLUE}处理应用: $app${NC}"
    
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
    
    echo "  🧹 清理模块缓存..."
    go clean -modcache 2>/dev/null || true
    
    echo "  📥 整理依赖..."
    if go mod tidy; then
        echo -e "  ${GREEN}✅ go mod tidy 成功${NC}"
    else
        echo -e "  ${RED}❌ go mod tidy 失败${NC}"
        cd "../.."
        continue
    fi
    
    echo "  📦 下载依赖..."
    if go mod download; then
        echo -e "  ${GREEN}✅ go mod download 成功${NC}"
    else
        echo -e "  ${RED}❌ go mod download 失败${NC}"
        cd "../.."
        continue
    fi
    
    echo "  🔍 验证模块..."
    if go mod verify; then
        echo -e "  ${GREEN}✅ go mod verify 成功${NC}"
    else
        echo -e "  ${YELLOW}⚠️  go mod verify 有警告${NC}"
    fi
    
    echo -e "  ${GREEN}✅ $app 处理完成${NC}"
    echo ""
    
    cd "../.."
done

echo -e "${GREEN}🎉 所有依赖下载完成！${NC}"
echo ""

# 显示模块信息
echo -e "${YELLOW}📋 模块信息摘要:${NC}"
for app in "${apps[@]}"; do
    if [ -d "backend/$app" ]; then
        echo "应用: $app"
        cd "backend/$app"
        if [ -f "go.mod" ]; then
            echo "  模块: $(head -1 go.mod)"
            echo "  依赖数量: $(grep -c "^[[:space:]]*[^[:space:]#]" go.mod 2>/dev/null || echo "0")"
        fi
        cd "../.."
    fi
done

echo ""
echo -e "${BLUE}💡 提示:${NC}"
echo "  - 如果下载失败，请检查网络连接"
echo "  - 可以尝试不同的GOPROXY设置"
echo "  - 企业网络可能需要配置HTTP代理"
echo ""
echo -e "${GREEN}✨ 现在可以构建应用了: make build-backend${NC}"