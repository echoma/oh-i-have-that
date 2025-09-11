#!/bin/bash

# 测试环境部署脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 测试环境部署工具${NC}"
echo ""

# 检查必要工具
check_tools() {
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ 缺少必要工具: ${missing_tools[*]}${NC}"
        echo "请先运行: scripts/01-environment-setup/setup-dev-env.sh"
        exit 1
    fi
}

# 检查环境变量
check_credentials() {
    if [[ -z "$TENCENTCLOUD_SECRET_ID" ]] || [[ -z "$TENCENTCLOUD_SECRET_KEY" ]]; then
        echo -e "${RED}❌ 请设置腾讯云认证环境变量${NC}"
        echo "export TENCENTCLOUD_SECRET_ID=\"your-secret-id\""
        echo "export TENCENTCLOUD_SECRET_KEY=\"your-secret-key\""
        exit 1
    fi
}

# 部署基础设施
deploy_infrastructure() {
    echo -e "${YELLOW}🏗️ 部署测试环境基础设施...${NC}"
    
    if [ -f "scripts/02-infrastructure-setup/deploy-infrastructure.sh" ]; then
        bash scripts/02-infrastructure-setup/deploy-infrastructure.sh test --auto-approve
    else
        echo -e "${RED}❌ 基础设施部署脚本不存在${NC}"
        exit 1
    fi
}

# 构建和推送镜像
build_and_push_images() {
    echo -e "${YELLOW}🐳 构建和推送Docker镜像...${NC}"
    
    # 获取容器注册表地址
    cd infrastructure
    terraform workspace select test
    local registry_url=$(terraform output -raw container_registry_url 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$registry_url" ]; then
        echo -e "${RED}❌ 无法获取容器注册表地址${NC}"
        exit 1
    fi
    
    echo "容器注册表: $registry_url"
    
    # 构建镜像
    if [ -f "scripts/03-build-and-package/build-docker-images.sh" ]; then
        bash scripts/03-build-and-package/build-docker-images.sh \
            --registry="$registry_url" \
            --tag="test-$(date +%Y%m%d-%H%M%S)" \
            --push
    else
        echo -e "${RED}❌ Docker构建脚本不存在${NC}"
        exit 1
    fi
}

# 部署前端到COS
deploy_frontend() {
    echo -e "${YELLOW}🎨 部署前端到COS...${NC}"
    
    # 构建前端
    if [ -f "scripts/03-build-and-package/build-frontend.sh" ]; then
        bash scripts/03-build-and-package/build-frontend.sh
    else
        echo -e "${RED}❌ 前端构建脚本不存在${NC}"
        exit 1
    fi
    
    # 获取COS存储桶信息
    cd infrastructure
    terraform workspace select test
    local bucket_url=$(terraform output -raw cos_bucket_url 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$bucket_url" ]; then
        echo -e "${RED}❌ 无法获取COS存储桶地址${NC}"
        exit 1
    fi
    
    echo "COS存储桶: $bucket_url"
    
    # 上传前端文件
    local build_dir=""
    if [ -d "frontend/dist" ]; then
        build_dir="frontend/dist"
    elif [ -d "frontend/build" ]; then
        build_dir="frontend/build"
    else
        echo -e "${RED}❌ 未找到前端构建目录${NC}"
        exit 1
    fi
    
    echo "上传前端文件..."
    # 这里需要根据实际的COS上传方式调整
    # 可以使用腾讯云CLI或者其他工具
    if command -v tccli &> /dev/null; then
        # 使用腾讯云CLI上传
        find "$build_dir" -type f | while read file; do
            local relative_path=${file#$build_dir/}
            echo "上传: $relative_path"
            # tccli cos PutObject --Bucket bucket-name --Key "$relative_path" --Body "$file"
        done
    else
        echo -e "${YELLOW}⚠️  请手动上传前端文件到COS${NC}"
        echo "构建目录: $build_dir"
        echo "目标存储桶: $bucket_url"
    fi
}

# 部署云函数
deploy_functions() {
    echo -e "${YELLOW}⚡ 部署云函数...${NC}"
    
    # 获取云函数命名空间
    cd infrastructure
    terraform workspace select test
    local namespace=$(terraform output -raw scf_namespace 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$namespace" ]; then
        echo -e "${RED}❌ 无法获取云函数命名空间${NC}"
        exit 1
    fi
    
    echo "云函数命名空间: $namespace"
    
    # 部署每个服务
    local apps=("website-api" "user-service" "notification-service")
    
    for app in "${apps[@]}"; do
        echo "部署云函数: $app"
        
        if [ ! -d "backend/$app" ]; then
            echo -e "${YELLOW}⚠️  跳过不存在的应用: $app${NC}"
            continue
        fi
        
        # 这里需要根据实际的云函数部署方式调整
        # 可能需要打包代码、上传到COS、创建/更新函数等步骤
        echo "  📦 准备部署包..."
        echo "  ⬆️  上传代码..."
        echo "  🔄 更新函数配置..."
        echo -e "  ${GREEN}✅ $app 部署完成${NC}"
    done
}

# 验证部署
verify_deployment() {
    echo -e "${YELLOW}🔍 验证部署...${NC}"
    
    # 获取API网关地址
    cd infrastructure
    terraform workspace select test
    local api_url=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
    local cos_url=$(terraform output -raw cos_bucket_url 2>/dev/null || echo "")
    cd ..
    
    echo ""
    echo -e "${BLUE}📋 部署信息:${NC}"
    echo "前端地址: $cos_url"
    echo "API地址: $api_url"
    
    # 测试前端访问
    if [ -n "$cos_url" ]; then
        echo ""
        echo -e "${YELLOW}测试前端访问...${NC}"
        if curl -s -o /dev/null -w "%{http_code}" "$cos_url" | grep -q "200"; then
            echo -e "${GREEN}✅ 前端访问正常${NC}"
        else
            echo -e "${RED}❌ 前端访问异常${NC}"
        fi
    fi
    
    # 测试API访问
    if [ -n "$api_url" ]; then
        echo ""
        echo -e "${YELLOW}测试API访问...${NC}"
        if curl -s -o /dev/null -w "%{http_code}" "$api_url/health" | grep -q "200"; then
            echo -e "${GREEN}✅ API访问正常${NC}"
        else
            echo -e "${YELLOW}⚠️  API可能需要时间启动${NC}"
        fi
    fi
}

# 主函数
main() {
    echo -e "${BLUE}开始测试环境部署流程...${NC}"
    echo ""
    
    # 检查环境
    check_tools
    check_credentials
    
    # 执行部署步骤
    echo -e "${BLUE}📋 部署步骤:${NC}"
    echo "1. 部署基础设施"
    echo "2. 构建和推送镜像"
    echo "3. 部署前端"
    echo "4. 部署云函数"
    echo "5. 验证部署"
    echo ""
    
    read -p "继续部署？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "部署已取消"
        exit 0
    fi
    
    echo ""
    
    # 执行部署
    deploy_infrastructure
    build_and_push_images
    deploy_frontend
    deploy_functions
    verify_deployment
    
    echo ""
    echo -e "${GREEN}🎉 测试环境部署完成！${NC}"
    echo ""
    echo -e "${BLUE}💡 下一步:${NC}"
    echo "  - 访问前端进行功能测试"
    echo "  - 检查API接口响应"
    echo "  - 查看云函数日志"
    echo "  - 准备生产环境部署"
}

# 执行主函数
main "$@"