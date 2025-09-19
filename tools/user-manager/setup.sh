#!/bin/bash

# Oh I Have That 用户管理工具安装脚本

set -e

echo "🚀 Oh I Have That 用户管理工具安装向导"
echo "=================================="

# 检查操作系统
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "❌ 不支持的操作系统: $OSTYPE"
    exit 1
fi

echo "✅ 检测到操作系统: $OS"

# 检查必要的工具
echo ""
echo "🔍 检查依赖工具..."

check_tool() {
    if command -v $1 &> /dev/null; then
        echo "✅ $1 已安装"
        return 0
    else
        echo "❌ $1 未安装"
        return 1
    fi
}

# 检查基础工具
MISSING_TOOLS=()

if ! check_tool "curl"; then
    MISSING_TOOLS+=("curl")
fi

if ! check_tool "jq"; then
    MISSING_TOOLS+=("jq")
fi

if ! check_tool "openssl"; then
    MISSING_TOOLS+=("openssl")
fi

# 检查SHA工具
if ! check_tool "shasum"; then
    if ! check_tool "sha256sum"; then
        MISSING_TOOLS+=("shasum/sha256sum")
    fi
fi

# 安装缺失的工具
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo "📦 需要安装以下工具: ${MISSING_TOOLS[*]}"
    
    if [[ "$OS" == "macos" ]]; then
        echo ""
        echo "在macOS上安装："
        echo "brew install curl jq openssl"
    elif [[ "$OS" == "linux" ]]; then
        echo ""
        echo "在Ubuntu/Debian上安装："
        echo "sudo apt-get update && sudo apt-get install -y curl jq openssl"
        echo ""
        echo "在CentOS/RHEL上安装："
        echo "sudo yum install -y curl jq openssl"
    fi
    
    read -p "是否现在安装这些工具？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ "$OS" == "macos" ]]; then
            if command -v brew &> /dev/null; then
                brew install ${MISSING_TOOLS[*]}
            else
                echo "❌ 请先安装Homebrew: https://brew.sh/"
                exit 1
            fi
        elif [[ "$OS" == "linux" ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y ${MISSING_TOOLS[*]}
            elif command -v yum &> /dev/null; then
                sudo yum install -y ${MISSING_TOOLS[*]}
            else
                echo "❌ 不支持的包管理器"
                exit 1
            fi
        fi
    else
        echo "请手动安装缺失的工具后再运行此脚本"
        exit 1
    fi
fi

echo ""
echo "🔧 设置执行权限..."
chmod +x user_manager.sh

echo ""
echo "📝 环境变量配置..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "✅ 已创建 .env 文件，请编辑其中的配置"
    echo ""
    echo "需要配置以下环境变量："
    echo "- COS_DATA_BUCKET: COS数据桶名称"
    echo "- COS_REGION: COS区域"
    echo "- COS_SECRET_ID: 腾讯云访问密钥ID"
    echo "- COS_SECRET_KEY: 腾讯云访问密钥Key"
else
    echo "✅ .env 文件已存在"
fi

echo ""
echo "🎯 快速开始："
echo "1. 编辑 .env 文件，配置COS访问信息"
echo "2. 加载环境变量: source .env"
echo "3. 初始化用户数据: ./user_manager.sh init"
echo "4. 添加管理员用户: ./user_manager.sh add"
echo "5. 查看用户列表: ./user_manager.sh list"

echo ""
echo "✅ 安装完成！"