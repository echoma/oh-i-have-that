#!/bin/bash

# SCF网站部署脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查必要的工具
check_requirements() {
    log_info "检查部署环境..."
    
    # 检查Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform未安装，请先安装Terraform"
        exit 1
    fi
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    # 检查腾讯云CLI（可选）
    if ! command -v tccli &> /dev/null; then
        log_warning "腾讯云CLI未安装，建议安装以便更好地管理资源"
    fi
    
    log_success "环境检查完成"
}

# 设置环境变量
setup_environment() {
    log_info "设置环境变量..."
    
    # 检查必要的环境变量
    if [[ -z "$TENCENTCLOUD_SECRET_ID" ]]; then
        log_error "请设置环境变量 TENCENTCLOUD_SECRET_ID"
        exit 1
    fi
    
    if [[ -z "$TENCENTCLOUD_SECRET_KEY" ]]; then
        log_error "请设置环境变量 TENCENTCLOUD_SECRET_KEY"
        exit 1
    fi
    
    # 设置默认地域
    export TENCENTCLOUD_REGION=${TENCENTCLOUD_REGION:-"ap-guangzhou"}
    
    log_success "环境变量设置完成"
}

# 初始化Terraform
init_terraform() {
    log_info "初始化Terraform..."
    
    cd "$(dirname "$0")/.."
    
    terraform init
    
    log_success "Terraform初始化完成"
}

# 验证Terraform配置
validate_terraform() {
    log_info "验证Terraform配置..."
    
    terraform validate
    terraform fmt -check=true
    
    log_success "Terraform配置验证通过"
}

# 规划部署
plan_deployment() {
    log_info "生成部署计划..."
    
    local env=${1:-prod}
    local var_file="environments/${env}/terraform.tfvars"
    
    if [[ ! -f "$var_file" ]]; then
        log_error "环境配置文件不存在: $var_file"
        exit 1
    fi
    
    terraform plan -var-file="$var_file" -out=tfplan
    
    log_success "部署计划生成完成"
}

# 执行部署
apply_deployment() {
    log_info "开始部署..."
    
    terraform apply tfplan
    
    log_success "部署完成"
}

# 显示输出信息
show_outputs() {
    log_info "部署结果:"
    echo
    
    terraform output -json | jq -r '
        "COS存储桶URL: " + .cos_bucket_url.value,
        "SCF函数名称: " + .scf_function_name.value,
        "API网关URL: " + .scf_trigger_url.value,
        "Docker镜像URI: " + .docker_image_uri.value
    '
    
    echo
    log_success "您可以通过以上URL访问您的网站"
}

# 清理资源
destroy_resources() {
    log_warning "准备销毁所有资源..."
    
    local env=${1:-prod}
    local var_file="environments/${env}/terraform.tfvars"
    
    read -p "确定要销毁所有资源吗？这个操作不可逆转 (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        terraform destroy -var-file="$var_file"
        log_success "资源销毁完成"
    else
        log_info "取消销毁操作"
    fi
}

# 主函数
main() {
    local command=${1:-deploy}
    local environment=${2:-prod}
    
    case "$command" in
        "deploy")
            check_requirements
            setup_environment
            init_terraform
            validate_terraform
            plan_deployment "$environment"
            apply_deployment
            show_outputs
            ;;
        "plan")
            check_requirements
            setup_environment
            init_terraform
            validate_terraform
            plan_deployment "$environment"
            ;;
        "destroy")
            check_requirements
            setup_environment
            init_terraform
            destroy_resources "$environment"
            ;;
        "output")
            show_outputs
            ;;
        *)
            echo "用法: $0 {deploy|plan|destroy|output} [environment]"
            echo "  deploy  - 完整部署流程"
            echo "  plan    - 仅生成部署计划"
            echo "  destroy - 销毁所有资源"
            echo "  output  - 显示部署输出"
            echo ""
            echo "环境: prod (默认)"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"