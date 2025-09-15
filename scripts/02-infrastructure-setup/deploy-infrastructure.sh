#!/bin/bash

# 基础设施部署脚本 - 完整的部署流程管理
set -e

# 导入公共函数库
source "$(dirname "$0")/terraform-common.sh"

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
    echo "  --plan-only      仅生成部署计划，不执行部署"
    echo "  --auto-approve   自动批准部署，不需要确认"
    echo "  --target=MODULE  仅部署指定模块"
    echo "  --staged         分阶段部署（逐个模块确认）"
    echo "  --init           强制重新初始化"
    echo ""
    echo "示例:"
    echo "  $0 test                      # 部署测试环境"
    echo "  $0 prod --plan-only          # 查看生产环境部署计划"
    echo "  $0 test --target=module.cos  # 仅部署COS模块"
    echo "  $0 prod --staged             # 分阶段部署生产环境"
}

# 分阶段部署
staged_deployment() {
    local env=$1
    local auto_approve=$2
    
    log_info "开始分阶段部署..."
    
    # 当前可用的模块（根据实际情况调整）
    local stages=("network" "cos")
    
    for stage in "${stages[@]}"; do
        log_info "部署阶段: $stage"
        
        # 生成计划
        if ! terraform_plan "$env" "module.$stage" "tfplan-$stage"; then
            log_error "阶段 $stage 计划生成失败"
            return 1
        fi
        
        # 执行部署
        if [[ "$auto_approve" == "true" ]]; then
            if terraform_apply "tfplan-$stage" true; then
                log_success "$stage 模块部署完成"
            else
                log_error "$stage 模块部署失败"
                return 1
            fi
        else
            echo "准备部署 $stage 模块..."
            read -p "继续？(y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if terraform_apply "tfplan-$stage" false; then
                    log_success "$stage 模块部署完成"
                else
                    log_error "$stage 模块部署失败"
                    return 1
                fi
            else
                log_warning "跳过 $stage 模块部署"
                continue
            fi
        fi
        
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
    local force_init=false
    
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
            --init)
                force_init=true
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
    
    if ! validate_environment "$environment"; then
        exit 1
    fi
    
    echo -e "${BLUE}🏗️ 基础设施部署工具${NC}"
    echo "环境: $environment"
    echo "仅计划: $plan_only"
    echo "自动批准: $auto_approve"
    echo "目标模块: ${target:-"全部"}"
    echo "分阶段部署: $staged"
    echo ""
    
    # 切换到infrastructure目录
    if ! ensure_infrastructure_dir; then
        exit 1
    fi
    
    # 执行部署流程
    log_info "开始基础设施部署流程..."
    
    # 1. 检查环境要求
    if ! check_requirements; then
        exit 1
    fi
    
    # 2. 初始化Terraform（如果需要）
    if [[ "$force_init" == "true" ]]; then
        if ! confirm_state_bucket; then
            exit 1
        fi
        if ! terraform_init "$environment" true; then
            exit 1
        fi
    else
        # 尝试选择工作空间，如果失败则初始化
        if ! terraform_workspace_select "$environment"; then
            log_info "工作空间不存在，开始初始化..."
            if ! confirm_state_bucket; then
                exit 1
            fi
            if ! terraform_init "$environment" false; then
                exit 1
            fi
        fi
    fi
    
    # 3. 验证配置
    if ! terraform_validate; then
        exit 1
    fi
    
    # 4. 执行部署策略
    if [[ "$staged" == "true" ]]; then
        # 分阶段部署
        if [[ "$plan_only" == "false" ]]; then
            if staged_deployment "$environment" "$auto_approve"; then
                terraform_show_outputs
            else
                exit 1
            fi
        else
            log_info "分阶段部署不支持仅计划模式"
            exit 1
        fi
    else
        # 标准部署流程
        # 生成计划
        if ! terraform_plan "$environment" "$target"; then
            exit 1
        fi
        
        # 执行部署（如果不是仅计划模式）
        if [[ "$plan_only" == "false" ]]; then
            if terraform_apply "tfplan-$environment" "$auto_approve"; then
                terraform_show_outputs
            else
                exit 1
            fi
        else
            log_info "仅生成计划，未执行部署"
        fi
    fi
    
    echo ""
    log_success "🎉 基础设施部署流程完成！"
}

# 执行主函数
main "$@"