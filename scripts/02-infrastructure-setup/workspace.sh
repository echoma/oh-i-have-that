#!/bin/bash

# Terraform工作空间管理脚本
set -e

# 导入公共函数库
source "$(dirname "$0")/terraform-common.sh"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Terraform工作空间管理工具${NC}"
    echo ""
    echo "用法: $0 [命令] [环境]"
    echo ""
    echo "命令:"
    echo "  init     初始化指定环境"
    echo "  plan     查看指定环境的执行计划"
    echo "  apply    部署指定环境"
    echo "  destroy  销毁指定环境资源"
    echo "  switch   切换到指定环境"
    echo "  list     列出所有环境"
    echo "  status   显示当前环境状态"
    echo ""
    echo "环境:"
    echo "  test     测试环境"
    echo "  prod     生产环境"
    echo ""
    echo "示例:"
    echo "  $0 init test     # 初始化测试环境"
    echo "  $0 apply prod    # 部署生产环境"
    echo "  $0 switch test   # 切换到测试环境"
}

# 检查参数
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

COMMAND=$1
ENVIRONMENT=${2:-""}

# 需要环境参数的命令
case $COMMAND in
    "init"|"plan"|"apply"|"destroy"|"switch")
        if [[ -z "$ENVIRONMENT" ]]; then
            log_error "命令 '$COMMAND' 需要指定环境参数"
            show_help
            exit 1
        fi
        
        if ! validate_environment "$ENVIRONMENT"; then
            exit 1
        fi
        ;;
esac

# 切换到infrastructure目录
if ! ensure_infrastructure_dir; then
    exit 1
fi

# 执行命令
case $COMMAND in
    "init")
        log_info "初始化 $ENVIRONMENT 环境..."
        
        # 检查环境要求
        if ! check_requirements; then
            exit 1
        fi
        
        # 确认状态存储桶
        if ! confirm_state_bucket; then
            exit 1
        fi
        
        # 初始化Terraform
        if terraform_init "$ENVIRONMENT" true; then
            log_success "$ENVIRONMENT 环境初始化完成"
        else
            exit 1
        fi
        ;;
        
    "plan")
        log_info "生成 $ENVIRONMENT 环境执行计划..."
        
        if terraform_workspace_select "$ENVIRONMENT" && terraform_plan "$ENVIRONMENT"; then
            log_success "执行计划生成完成"
        else
            exit 1
        fi
        ;;
        
    "apply")
        log_info "部署 $ENVIRONMENT 环境..."
        
        if terraform_workspace_select "$ENVIRONMENT" && terraform_apply "" false; then
            log_success "$ENVIRONMENT 环境部署完成"
        else
            exit 1
        fi
        ;;
        
    "destroy")
        if terraform_workspace_select "$ENVIRONMENT" && terraform_destroy "$ENVIRONMENT"; then
            log_success "$ENVIRONMENT 环境资源已销毁"
        else
            exit 1
        fi
        ;;
        
    "switch")
        if terraform_workspace_select "$ENVIRONMENT"; then
            log_success "已切换到 $ENVIRONMENT 环境"
        else
            exit 1
        fi
        ;;
        
    "list")
        terraform_workspace_list
        ;;
        
    "status")
        terraform_show_status
        ;;
        
    "help"|"-h"|"--help")
        show_help
        ;;
        
    *)
        log_error "未知命令 '$COMMAND'"
        show_help
        exit 1
        ;;
esac