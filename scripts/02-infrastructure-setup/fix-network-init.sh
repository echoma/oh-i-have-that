#!/bin/bash

# 网络问题修复脚本
# 用于解决 Terraform 初始化时的网络连接问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Terraform 网络问题修复工具${NC}"
    echo ""
    echo "用法: $0 [环境]"
    echo ""
    echo "环境:"
    echo "  test     测试环境"
    echo "  prod     生产环境"
    echo ""
    echo "此脚本将："
    echo "1. 清理 Terraform 缓存"
    echo "2. 使用离线模式重新初始化"
    echo "3. 配置适当的网络设置"
}

# 检查参数
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

ENVIRONMENT=$1

# 验证环境参数
if [ "$ENVIRONMENT" != "test" ] && [ "$ENVIRONMENT" != "prod" ]; then
    log_error "无效的环境 '$ENVIRONMENT'"
    log_warning "支持的环境: test, prod"
    exit 1
fi

# 切换到infrastructure目录
SCRIPT_DIR="$(dirname "$0")"
INFRA_DIR="$SCRIPT_DIR/../../infrastructure"

if [[ ! -d "$INFRA_DIR" ]]; then
    log_error "Infrastructure目录不存在: $INFRA_DIR"
    exit 1
fi

cd "$INFRA_DIR"

log_info "开始修复 $ENVIRONMENT 环境的网络初始化问题..."

# 步骤1: 清理 Terraform 缓存
log_info "步骤1: 清理 Terraform 缓存..."
if [ -d ".terraform" ]; then
    rm -rf .terraform
    log_success "已清理 .terraform 目录"
else
    log_info ".terraform 目录不存在，跳过清理"
fi

# 步骤2: 检查配置文件
log_info "步骤2: 检查配置文件..."
if [[ ! -f "environments/$ENVIRONMENT/terraform.tfvars" ]]; then
    log_error "环境变量文件不存在: environments/$ENVIRONMENT/terraform.tfvars"
    exit 1
fi

if [[ ! -f "environments/$ENVIRONMENT/backend.hcl" ]]; then
    log_error "后端配置文件不存在: environments/$ENVIRONMENT/backend.hcl"
    exit 1
fi

log_success "配置文件检查完成"

# 步骤3: 检查网络连接
log_info "步骤3: 诊断网络连接..."

# 检查基本网络
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_success "基本网络连接正常"
else
    log_error "网络连接异常，请检查网络设置"
    exit 1
fi

# 检查DNS解析
if nslookup registry.terraform.io >/dev/null 2>&1; then
    log_success "DNS解析正常"
    NETWORK_OK=true
else
    log_warning "DNS解析异常，将使用离线模式"
    NETWORK_OK=false
fi

# 检查HTTPS连接
if curl -s --connect-timeout 5 https://registry.terraform.io/.well-known/terraform.json >/dev/null 2>&1; then
    log_success "Terraform Registry 连接正常"
    NETWORK_OK=true
else
    log_warning "无法连接到 Terraform Registry，将使用离线模式"
    NETWORK_OK=false
fi

# 步骤4: 执行初始化
log_info "步骤4: 执行 Terraform 初始化..."

# 构建初始化参数
INIT_ARGS="-backend-config=environments/$ENVIRONMENT/backend.hcl -reconfigure"

if [ "$NETWORK_OK" = false ]; then
    log_info "使用离线模式初始化..."
    INIT_ARGS="$INIT_ARGS -upgrade=false"
fi

log_info "执行命令: terraform init $INIT_ARGS"

if terraform init $INIT_ARGS; then
    log_success "Terraform 初始化成功"
else
    log_error "Terraform 初始化失败"
    echo ""
    log_info "可能的解决方案："
    log_info "1. 检查腾讯云认证信息："
    echo "   export TENCENTCLOUD_SECRET_ID=\"your-secret-id\""
    echo "   export TENCENTCLOUD_SECRET_KEY=\"your-secret-key\""
    log_info "2. 检查网络设置，确保可以访问腾讯云API"
    log_info "3. 如果在企业网络，联系网络管理员配置代理"
    log_info "4. 尝试更换DNS服务器 (如: 8.8.8.8)"
    exit 1
fi

# 步骤5: 创建或选择工作空间
log_info "步骤5: 配置工作空间..."

if terraform workspace new "$ENVIRONMENT" 2>/dev/null; then
    log_success "已创建工作空间: $ENVIRONMENT"
elif terraform workspace select "$ENVIRONMENT"; then
    log_success "已选择工作空间: $ENVIRONMENT"
else
    log_error "工作空间配置失败"
    exit 1
fi

# 步骤6: 验证配置
log_info "步骤6: 验证 Terraform 配置..."

if terraform validate; then
    log_success "配置验证通过"
else
    log_error "配置验证失败"
    exit 1
fi

echo ""
log_success "🎉 $ENVIRONMENT 环境初始化修复完成！"
echo ""
log_info "接下来您可以："
log_info "1. 运行计划: terraform plan -var-file=environments/$ENVIRONMENT/terraform.tfvars"
log_info "2. 执行部署: terraform apply -var-file=environments/$ENVIRONMENT/terraform.tfvars"
log_info "3. 或使用脚本: ../scripts/02-infrastructure-setup/workspace.sh plan $ENVIRONMENT"