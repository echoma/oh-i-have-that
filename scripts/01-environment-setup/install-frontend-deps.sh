#!/bin/bash

# 前端依赖安装脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 前端依赖安装工具${NC}"
echo ""

# 检查Node.js环境
echo -e "${YELLOW}🔍 检查Node.js环境...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js未安装或不在PATH中${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm未安装或不在PATH中${NC}"
    exit 1
fi

NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo "Node.js版本: $NODE_VERSION"
echo "npm版本: $NPM_VERSION"
echo ""

# 配置npm
echo -e "${YELLOW}⚙️ 配置npm...${NC}"
npm config set registry https://registry.npmmirror.com
echo "npm镜像源: $(npm config get registry)"
echo ""

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

echo -e "${BLUE}📋 项目信息:${NC}"
echo "项目名称: $(cat package.json | grep '"name"' | cut -d'"' -f4)"
echo "项目版本: $(cat package.json | grep '"version"' | cut -d'"' -f4)"
echo ""

# 清理现有依赖
echo -e "${YELLOW}🧹 清理现有依赖...${NC}"
rm -rf node_modules package-lock.json 2>/dev/null || true
npm cache clean --force
echo ""

# 安装依赖
echo -e "${YELLOW}📦 安装依赖...${NC}"
if npm install; then
    echo -e "${GREEN}✅ 依赖安装成功${NC}"
else
    echo -e "${RED}❌ 依赖安装失败${NC}"
    exit 1
fi

echo ""

# 显示依赖信息
echo -e "${BLUE}📊 依赖统计:${NC}"
TOTAL_DEPS=$(npm list --depth=0 2>/dev/null | grep -c "├──\|└──" || echo "0")
echo "总依赖数量: $TOTAL_DEPS"

if [ -f "package-lock.json" ]; then
    LOCK_SIZE=$(du -sh package-lock.json | cut -f1)
    echo "package-lock.json大小: $LOCK_SIZE"
fi

if [ -d "node_modules" ]; then
    NODE_MODULES_SIZE=$(du -sh node_modules | cut -f1)
    echo "node_modules大小: $NODE_MODULES_SIZE"
fi

echo ""

# 验证安装
echo -e "${YELLOW}🔍 验证安装...${NC}"

# 检查关键依赖
key_deps=("vite" "vue" "react" "webpack")
for dep in "${key_deps[@]}"; do
    if npm list $dep &>/dev/null; then
        version=$(npm list $dep --depth=0 2>/dev/null | grep $dep | cut -d'@' -f2 || echo "unknown")
        echo -e "${GREEN}✅ $dep@$version${NC}"
    fi
done

echo ""

# 测试构建脚本
echo -e "${YELLOW}🧪 测试构建脚本...${NC}"
if npm run build --dry-run &>/dev/null; then
    echo -e "${GREEN}✅ 构建脚本配置正确${NC}"
else
    echo -e "${YELLOW}⚠️  构建脚本可能需要调整${NC}"
fi

# 测试开发服务器
if npm run dev --help &>/dev/null; then
    echo -e "${GREEN}✅ 开发服务器脚本配置正确${NC}"
else
    echo -e "${YELLOW}⚠️  开发服务器脚本可能需要调整${NC}"
fi

cd ..

echo ""
echo -e "${GREEN}🎉 前端依赖安装完成！${NC}"
echo ""
echo -e "${BLUE}💡 下一步:${NC}"
echo "  - 启动开发服务器: cd frontend && npm run dev"
echo "  - 构建生产版本: cd frontend && npm run build"
echo "  - 查看可用脚本: cd frontend && npm run"
echo ""
echo -e "${YELLOW}📝 注意事项:${NC}"
echo "  - node_modules目录较大，建议添加到.gitignore"
echo "  - 定期更新依赖: npm update"
echo "  - 安全审计: npm audit"