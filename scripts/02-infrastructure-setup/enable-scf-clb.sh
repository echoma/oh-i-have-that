#!/bin/bash

# 启用SCF和CLB的部署脚本
set -e

# 导入公共函数库
source "$(dirname "$0")/terraform-common.sh"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}启用SCF和CLB部署工具${NC}"
    echo ""
    echo "用法: $0 [环境] [步骤]"
    echo ""
    echo "环境:"
    echo "  test     测试环境"
    echo "  prod     生产环境"
    echo ""
    echo "步骤:"
    echo "  1        仅启用容器注册表"
    echo "  2        启用容器注册表 + Docker构建"
    echo "  3        启用容器注册表 + Docker构建 + SCF"
    echo "  4        启用完整架构 (容器注册表 + Docker + SCF + CLB)"
    echo ""
    echo "示例:"
    echo "  $0 test 1    # 测试环境，仅启用容器注册表"
    echo "  $0 test 4    # 测试环境，启用完整架构"
}

# 检查参数
if [ $# -lt 2 ]; then
    show_help
    exit 1
fi

ENVIRONMENT=$1
STEP=$2

# 验证环境参数
if ! validate_environment "$ENVIRONMENT"; then
    exit 1
fi

# 验证步骤参数
if [[ ! "$STEP" =~ ^[1-4]$ ]]; then
    log_error "无效的步骤 '$STEP'"
    log_warning "支持的步骤: 1, 2, 3, 4"
    exit 1
fi

# 切换到infrastructure目录
if ! ensure_infrastructure_dir; then
    exit 1
fi

# 检查环境要求
if ! check_requirements; then
    exit 1
fi

log_info "开始启用 $ENVIRONMENT 环境的SCF和CLB架构 (步骤 $STEP)..."

# 备份当前的main.tf
cp main.tf main.tf.backup.$(date +%Y%m%d_%H%M%S)
log_info "已备份当前配置到 main.tf.backup.*"

# 根据步骤修改配置
case $STEP in
    "1")
        log_info "步骤1: 仅启用容器注册表模块"
        # 创建临时配置文件，只启用容器注册表
        cat > main.tf.temp << 'EOF'
# 主配置文件

# 配置腾讯云Provider
provider "tencentcloud" {
  region = var.region
}

# 网络模块
module "network" {
  source = "./modules/network"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  tags = var.common_tags
}

# COS模块
module "cos" {
  source = "./modules/cos"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  # 静态网站配置
  bucket_name         = var.cos_bucket_name
  static_files_path   = var.static_files_path
  enable_auto_upload  = var.enable_auto_upload
  app_id             = var.app_id
  
  tags = var.common_tags
}

# 容器注册表模块
module "container_registry" {
  source = "./modules/container-registry"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  app_names = var.app_names
  app_id    = var.app_id
  
  tags = var.common_tags
}
EOF
        ;;
        
    "2")
        log_info "步骤2: 启用容器注册表 + Docker构建"
        # 创建临时配置文件，启用容器注册表和Docker
        cat > main.tf.temp << 'EOF'
# 主配置文件

# 配置腾讯云Provider
provider "tencentcloud" {
  region = var.region
}

# 网络模块
module "network" {
  source = "./modules/network"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  tags = var.common_tags
}

# COS模块
module "cos" {
  source = "./modules/cos"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  # 静态网站配置
  bucket_name         = var.cos_bucket_name
  static_files_path   = var.static_files_path
  enable_auto_upload  = var.enable_auto_upload
  app_id             = var.app_id
  
  tags = var.common_tags
}

# 容器注册表模块
module "container_registry" {
  source = "./modules/container-registry"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  app_names = var.app_names
  app_id    = var.app_id
  
  tags = var.common_tags
}

# Docker构建模块
module "docker" {
  source = "./modules/docker"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  app_names    = var.app_names
  registry_url = module.container_registry.registry_url
  image_uris   = module.container_registry.image_uris
  
  tags = var.common_tags
  
  depends_on = [module.container_registry]
}
EOF
        ;;
        
    "3")
        log_info "步骤3: 启用容器注册表 + Docker构建 + SCF"
        # 创建临时配置文件，启用到SCF
        cat > main.tf.temp << 'EOF'
# 主配置文件

# 配置腾讯云Provider
provider "tencentcloud" {
  region = var.region
}

# 网络模块
module "network" {
  source = "./modules/network"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  tags = var.common_tags
}

# COS模块
module "cos" {
  source = "./modules/cos"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  # 静态网站配置
  bucket_name         = var.cos_bucket_name
  static_files_path   = var.static_files_path
  enable_auto_upload  = var.enable_auto_upload
  app_id             = var.app_id
  
  tags = var.common_tags
}

# 容器注册表模块
module "container_registry" {
  source = "./modules/container-registry"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  app_names = var.app_names
  app_id    = var.app_id
  
  tags = var.common_tags
}

# Docker构建模块
module "docker" {
  source = "./modules/docker"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  app_names    = var.app_names
  registry_url = module.container_registry.registry_url
  image_uris   = module.container_registry.image_uris
  
  tags = var.common_tags
  
  depends_on = [module.container_registry]
}

# SCF模块
module "scf" {
  source = "./modules/scf"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  vpc_id    = module.network.vpc_id
  subnet_id = module.network.subnet_id
  
  # SCF配置
  function_name = var.scf_function_name
  memory_size   = var.scf_memory_size
  timeout       = var.scf_timeout
  
  # 使用主要的website-api镜像
  image_uri = module.container_registry.image_uris["website-api"]
  
  tags = var.common_tags
  
  depends_on = [module.docker]
}
EOF
        ;;
        
    "4")
        log_info "步骤4: 启用完整架构 (容器注册表 + Docker + SCF + CLB)"
        # 使用当前的main.tf (已经包含完整配置)
        log_info "使用当前的完整配置"
        ;;
esac

# 如果不是步骤4，替换main.tf
if [ "$STEP" != "4" ]; then
    mv main.tf.temp main.tf
    log_success "已更新配置文件"
fi

# 初始化Terraform (如果需要)
log_info "检查Terraform初始化状态..."
if ! terraform workspace select "$ENVIRONMENT" 2>/dev/null; then
    log_info "重新初始化Terraform..."
    if ! terraform_init "$ENVIRONMENT" true; then
        log_error "Terraform初始化失败"
        exit 1
    fi
else
    log_success "Terraform已初始化"
fi

# 生成执行计划
log_info "生成执行计划..."
if terraform_plan "$ENVIRONMENT"; then
    log_success "执行计划生成完成"
    echo ""
    log_info "请检查执行计划，确认无误后运行以下命令部署："
    echo "terraform apply $ENVIRONMENT.tfplan"
    echo ""
    log_info "或者使用脚本："
    echo "../scripts/02-infrastructure-setup/workspace.sh apply $ENVIRONMENT"
else
    log_error "执行计划生成失败"
    
    # 恢复备份
    log_info "恢复配置文件..."
    mv main.tf.backup.* main.tf 2>/dev/null || true
    
    exit 1
fi

echo ""
log_success "🎉 步骤 $STEP 配置完成！"
echo ""
log_info "下一步操作："
log_info "1. 检查执行计划是否符合预期"
log_info "2. 运行 terraform apply 部署资源"
log_info "3. 如果成功，可以尝试下一个步骤"
log_info "4. 如果失败，可以恢复备份: mv main.tf.backup.* main.tf"