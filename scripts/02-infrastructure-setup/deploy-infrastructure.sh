#!/bin/bash

# 基础设施部署脚本
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

# 显示帮助信息
show_help() {
    echo -e "${BLUE}基础设施部署工具${NC}"
    echo ""
    echo "用法: $0 [环境] [选项]"
    echo ""
    echo "环境:"
    echo "  test     部署测试环境"
    echo "  prod     部署生产环境"
    echo ""
    echo "选项:"
    echo "  --plan-only    仅生成部署计划，不执行部署"
    echo "  --auto-approve 自动批准部署，不需要确认"
    echo "  --target=MODULE 仅部署指定模块"
    echo ""
    echo "示例:"
    echo "  $0 test                    # 部署测试环境"
    echo "  $0 prod --plan-only        # 查看生产环境部署计划"
    echo "  $0 test --target=network   # 仅部署网络模块"
}

# 检查必要的工具和环境变量
check_requirements() {
    log_info "检查部署环境..."
    
    # 检查Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform未安装，请先安装Terraform"
        exit 1
    fi
    
    # 检查腾讯云认证
    if [[ -z "$TENCENTCLOUD_SECRET_ID" ]] || [[ -z "$TENCENTCLOUD_SECRET_KEY" ]]; then
        log_error "请设置腾讯云认证环境变量"
        echo "export TENCENTCLOUD_SECRET_ID=\"your-secret-id\""
        echo "export TENCENTCLOUD_SECRET_KEY=\"your-secret-key\""
        exit 1
    fi
    
    # 设置默认地域
    export TENCENTCLOUD_REGION=${TENCENTCLOUD_REGION:-"ap-guangzhou"}
    
    log_success "环境检查完成"
}

# 初始化Terraform
init_terraform() {
    local env=$1
    
    log_info "初始化Terraform环境: $env"
    
    # 切换到infrastructure目录
    cd infrastructure
    
    # 创建或选择工作空间
    terraform workspace new $env 2>/dev/null || terraform workspace select $env
    
    # 初始化Terraform
    if [ -f "environments/$env/backend.hcl" ]; then
        if terraform init -backend-config="environments/$env/backend.hcl"; then
            log_success "Terraform初始化完成"
        else
            log_error "Terraform初始化失败"
            exit 1
        fi
    else
        if terraform init; then
            log_success "Terraform初始化完成"
        else
            log_error "Terraform初始化失败"
            exit 1
        fi
    fi
}

# 验证配置
validate_config() {
    local env=$1
    
    log_info "验证Terraform配置..."
    
    # 验证语法
    terraform validate
    
    # 格式化检查
    terraform fmt -check=true
    
    # 检查配置文件
    local var_file="environments/$env/terraform.tfvars"
    if [[ ! -f "$var_file" ]]; then
        log_error "环境配置文件不存在: $var_file"
        exit 1
    fi
    
    log_success "配置验证通过"
}

# 生成部署计划
plan_deployment() {
    local env=$1
    local target=$2
    
    log_info "生成部署计划..."
    
    local var_file="environments/$env/terraform.tfvars"
    local plan_args="-var-file=$var_file -out=tfplan-$env"
    
    if [[ -n "$target" ]]; then
        plan_args="$plan_args -target=module.$target"
        log_info "仅规划模块: $target"
    fi
    
    if terraform plan $plan_args; then
        log_success "部署计划生成完成"
    else
        log_error "部署计划生成失败"
        exit 1
    fi
}

# 执行部署
apply_deployment() {
    local env=$1
    local auto_approve=$2
    
    log_info "开始部署基础设施..."
    
    local apply_args="tfplan-$env"
    
    if [[ "$auto_approve" == "true" ]]; then
        if terraform apply -auto-approve $apply_args; then
            log_success "基础设施部署完成"
        else
            log_error "基础设施部署失败"
            exit 1
        fi
    else
        if terraform apply $apply_args; then
            log_success "基础设施部署完成"
        else
            log_error "基础设施部署失败"
            exit 1
        fi
    fi
}

# 显示部署结果
show_outputs() {
    local env=$1
    
    log_info "部署结果:"
    echo ""
    
    # 显示重要输出
    if terraform output cos_bucket_url &>/dev/null; then
        echo "COS存储桶URL: $(terraform output -raw cos_bucket_url)"
    fi
    
    if terraform output container_registry_url &>/dev/null; then
        echo "容器注册表URL: $(terraform output -raw container_registry_url)"
    fi
    
    if terraform output scf_namespace &>/dev/null; then
        echo "云函数命名空间: $(terraform output -raw scf_namespace)"
    fi
    
    if terraform output api_gateway_url &>/dev/null; then
        echo "API网关URL: $(terraform output -raw api_gateway_url)"
    fi
    
    echo ""
    log_success "您可以通过以上信息访问和管理您的资源"
}

# 分阶段部署
staged_deployment() {
    local env=$1
    local auto_approve=$2
    
    log_info "开始分阶段部署..."
    
    local stages=("network" "cos" "container_registry" "scf")
    local var_file="environments/$env/terraform.tfvars"
    
    for stage in "${stages[@]}"; do
        log_info "部署阶段: $stage"
        
        # 生成计划
        terraform plan -target=module.$stage -var-file=$var_file -out=tfplan-$stage
        
        # 执行部署
        if [[ "$auto_approve" == "true" ]]; then
            terraform apply -auto-approve tfplan-$stage
        else
            echo "准备部署 $stage 模块..."
            read -p "继续？(y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                terraform apply tfplan-$stage
            else
                log_warning "跳过 $stage 模块部署"
                continue
            fi
        fi
        
        log_success "$stage 模块部署完成"
        echo ""
    done
    
    log_success "分阶段部署完成"
}

# 主函数
main() {
    local environment=""
    local plan_only=false
    local auto_approve=false
    local target=""
    local staged=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            test|prod)
                environment="$1"
                shift
                ;;
            --plan-only)
                plan_only=true
                shift
                ;;
            --auto-approve)
                auto_approve=true
                shift
                ;;
            --target=*)
                target="${1#*=}"
                shift
                ;;
            --staged)
                staged=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查参数
    if [[ -z "$environment" ]]; then
        log_error "请指定环境 (test 或 prod)"
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}🏗️ 基础设施部署工具${NC}"
    echo "环境: $environment"
    echo "仅计划: $plan_only"
    echo "自动批准: $auto_approve"
    echo "目标模块: ${target:-"全部"}"
    echo ""
    
    # 执行部署流程
    check_requirements
    init_terraform $environment
    validate_config $environment
    
    if [[ "$staged" == "true" ]]; then
        if [[ "$plan_only" == "false" ]]; then
            staged_deployment $environment $auto_approve
            show_outputs $environment
        else
            log_info "分阶段部署不支持仅计划模式"
        fi
    else
        plan_deployment $environment $target
        
        if [[ "$plan_only" == "false" ]]; then
            apply_deployment $environment $auto_approve
            show_outputs $environment
        else
            log_info "仅生成计划，未执行部署"
        fi
    fi
    
    # 返回原目录
    cd ..
    
    echo ""
    log_success "🎉 基础设施部署流程完成！"
}

# 执行主函数
main "$@"