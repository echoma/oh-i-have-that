#!/bin/bash

# 前端构建脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎨 前端构建工具${NC}"
echo ""

# 检查Node.js环境
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js未安装${NC}"
    echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm未安装${NC}"
    exit 1
fi

echo "Node.js版本: $(node --version)"
echo "npm版本: $(npm --version)"
echo ""

# 检查前端目录
if [ ! -d "frontend" ]; then
    echo -e "${RED}❌ frontend目录不存在${NC}"
    exit 1
fi

cd frontend

# 检查依赖
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}📦 安装依赖...${NC}"
    npm install
fi

# 清理构建目录
echo -e "${YELLOW}🧹 清理构建目录...${NC}"
rm -rf dist build

# 构建项目
echo -e "${YELLOW}🔨 构建前端项目...${NC}"
if npm run build; then
    echo -e "${GREEN}✅ 前端构建成功${NC}"
else
    echo -e "${RED}❌ 前端构建失败${NC}"
    exit 1
fi

# 检查构建结果
if [ -d "dist" ]; then
    BUILD_DIR="dist"
elif [ -d "build" ]; then
    BUILD_DIR="build"
else
    echo -e "${RED}❌ 未找到构建输出目录${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📊 构建统计:${NC}"
echo "构建目录: $BUILD_DIR"
echo "文件数量: $(find $BUILD_DIR -type f | wc -l)"
echo "总大小: $(du -sh $BUILD_DIR | cut -f1)"

# 列出主要文件
echo ""
echo -e "${BLUE}📁 主要文件:${NC}"
find $BUILD_DIR -name "*.html" -o -name "*.js" -o -name "*.css" | head -10

cd ..

echo ""
echo -e "${GREEN}🎉 前端构建完成！${NC}"
echo "构建输出: frontend/$BUILD_DIR"