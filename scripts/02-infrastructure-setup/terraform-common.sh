#!/bin/bash

# Terraform公共函数库
# 提供所有脚本共用的Terraform操作函数

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

# 验证环境参数
validate_environment() {
    local env=$1
    if [ "$env" != "test" ] && [ "$env" != "prod" ]; then
        log_error "无效的环境 '$env'"
        log_warning "支持的环境: test, prod"
        return 1
    fi
}

# 检查必要的工具和环境变量
check_requirements() {
    log_info "检查部署环境..."
    
    # 检查Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform未安装，请先安装Terraform"
        return 1
    fi
    
    # 检查腾讯云认证
    if [[ -z "$TENCENTCLOUD_SECRET_ID" ]] || [[ -z "$TENCENTCLOUD_SECRET_KEY" ]]; then
        log_error "请设置腾讯云认证环境变量"
        echo "export TENCENTCLOUD_SECRET_ID=\"your-secret-id\""
        echo "export TENCENTCLOUD_SECRET_KEY=\"your-secret-key\""
        return 1
    fi
    
    # 设置默认地域
    export TENCENTCLOUD_REGION=${TENCENTCLOUD_REGION:-"ap-guangzhou"}
    
    # 检查网络连接
    check_network_connectivity
    
    log_success "环境检查完成"
}

# 检查网络连接
check_network_connectivity() {
    log_info "检查网络连接..."
    
    # 检查基本网络连接
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_warning "网络连接异常，请检查网络设置"
        return 1
    fi
    
    # 检查DNS解析
    if ! nslookup registry.terraform.io >/dev/null 2>&1; then
        log_warning "无法解析 registry.terraform.io，可能是DNS问题"
        log_info "建议解决方案："
        log_info "1. 更换DNS服务器 (如: 8.8.8.8, 114.114.114.114)"
        log_info "2. 检查防火墙设置"
        log_info "3. 如果在企业网络，联系网络管理员"
        return 1
    fi
    
    # 检查HTTPS连接
    if ! curl -s --connect-timeout 10 https://registry.terraform.io/.well-known/terraform.json >/dev/null 2>&1; then
        log_warning "无法连接到 Terraform Registry"
        log_info "将尝试使用离线模式初始化"
        return 1
    fi
    
    log_success "网络连接正常"
    return 0
}

# 切换到infrastructure目录
ensure_infrastructure_dir() {
    local script_dir="$(dirname "${BASH_SOURCE[1]}")"
    local infra_dir="$script_dir/../../infrastructure"
    
    if [[ ! -d "$infra_dir" ]]; then
        log_error "Infrastructure目录不存在: $infra_dir"
        return 1
    fi
    
    cd "$infra_dir"
}

# 检查配置文件
check_config_files() {
    local env=$1
    
    if [[ ! -f "environments/$env/terraform.tfvars" ]]; then
        log_error "环境变量文件不存在: environments/$env/terraform.tfvars"
        return 1
    fi
    
    if [[ ! -f "environments/$env/backend.hcl" ]]; then
        log_error "后端配置文件不存在: environments/$env/backend.hcl"
        return 1
    fi
}

# 初始化Terraform工作空间
terraform_init() {
    local env=$1
    local reconfigure=${2:-false}
    
    log_info "初始化Terraform环境: $env"
    
    # 检查配置文件
    if ! check_config_files "$env"; then
        return 1
    fi
    
    # 初始化参数
    local init_args="-backend-config=environments/$env/backend.hcl"
    
    # 检查是否需要重新配置
    if [[ "$reconfigure" == "true" ]] || [[ -f ".terraform/terraform.tfstate" ]]; then
        log_warning "检测到backend配置变更，使用 -reconfigure 标志"
        init_args="$init_args -reconfigure"
    fi
    
    # 检查网络连接
    if ! curl -s --connect-timeout 5 https://registry.terraform.io/.well-known/terraform.json >/dev/null 2>&1; then
        log_warning "无法连接到 registry.terraform.io，尝试使用离线模式"
        init_args="$init_args -upgrade=false"
    fi
    
    # 执行初始化
    log_info "执行: terraform init $init_args"
    if terraform init $init_args; then
        log_success "Terraform初始化完成"
        
        # 创建或选择工作空间
        terraform workspace new "$env" 2>/dev/null || terraform workspace select "$env"
        return 0
    else
        log_error "Terraform初始化失败"
        log_info "尝试解决方案："
        log_info "1. 检查网络连接到 registry.terraform.io"
        log_info "2. 如果网络正常，尝试删除 .terraform 目录后重试"
        log_info "3. 检查腾讯云认证信息是否正确"
        return 1
    fi
}

# 切换工作空间
terraform_workspace_select() {
    local env=$1
    
    if terraform workspace select "$env"; then
        log_success "已切换到 $env 环境"
        return 0
    else
        log_error "切换到 $env 环境失败"
        return 1
    fi
}

# 验证Terraform配置
terraform_validate() {
    log_info "验证Terraform配置..."
    
    if terraform validate; then
        log_success "配置验证通过"
        return 0
    else
        log_error "配置验证失败"
        return 1
    fi
}

# 生成Terraform计划
terraform_plan() {
    local env=$1
    local target=$2
    local out_file=${3:-"$env.tfplan"}
    
    log_info "生成部署计划..."
    
    local var_file="environments/$env/terraform.tfvars"
    local plan_args="-var-file=$var_file -out=$out_file"
    
    if [[ -n "$target" ]]; then
        plan_args="$plan_args -target=$target"
        log_info "仅规划目标: $target"
    fi
    
    if terraform plan $plan_args; then
        log_success "部署计划生成完成"
        return 0
    else
        log_error "部署计划生成失败"
        return 1
    fi
}

# 执行Terraform应用
terraform_apply() {
    local plan_file=$1
    local auto_approve=${2:-false}
    
    log_info "执行Terraform部署..."
    
    local apply_args=""
    if [[ -n "$plan_file" ]]; then
        apply_args="$plan_file"
    fi
    
    if [[ "$auto_approve" == "true" ]]; then
        apply_args="$apply_args -auto-approve"
    fi
    
    if terraform apply $apply_args; then
        log_success "Terraform部署完成"
        return 0
    else
        log_error "Terraform部署失败"
        return 1
    fi
}

# 执行Terraform销毁
terraform_destroy() {
    local env=$1
    local auto_approve=${2:-false}
    
    log_warning "准备销毁 $env 环境的所有资源"
    log_error "这个操作不可逆！"
    
    if [[ "$auto_approve" != "true" ]]; then
        read -p "确认继续？(输入 'yes' 确认): " confirm
        if [ "$confirm" != "yes" ]; then
            log_warning "操作已取消"
            return 1
        fi
    fi
    
    local var_file="environments/$env/terraform.tfvars"
    local destroy_args="-var-file=$var_file"
    
    if [[ "$auto_approve" == "true" ]]; then
        destroy_args="$destroy_args -auto-approve"
    fi
    
    if terraform destroy $destroy_args; then
        log_success "$env 环境资源已销毁"
        return 0
    else
        log_error "资源销毁失败"
        return 1
    fi
}

# 显示工作空间列表
terraform_workspace_list() {
    log_info "可用的环境:"
    terraform workspace list
    
    echo ""
    log_info "当前环境:"
    terraform workspace show
}

# 显示资源状态
terraform_show_status() {
    log_info "当前环境状态:"
    echo "工作空间: $(terraform workspace show)"
    echo ""
    
    # 显示资源状态
    if terraform state list >/dev/null 2>&1; then
        log_success "已部署的资源:"
        terraform state list | head -10
        
        resource_count=$(terraform state list | wc -l)
        if [ $resource_count -gt 10 ]; then
            echo "... 还有 $((resource_count - 10)) 个资源"
        fi
    else
        log_warning "未找到已部署的资源"
    fi
}

# 显示Terraform输出
terraform_show_outputs() {
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

# 确认状态存储桶
confirm_state_bucket() {
    log_warning "⚠️  请确认您已在腾讯云控制台手动创建了状态存储桶"
    echo "存储桶名称应为: tfstate-oihavethat-xxxxxx (腾讯云会自动添加后缀)"
    read -p "是否已创建状态存储桶？(y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warning "请先在腾讯云控制台创建状态存储桶，然后重新运行此命令"
        return 1
    fi
    return 0
}