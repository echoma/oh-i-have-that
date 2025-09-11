#!/bin/bash

# Terraform工作空间管理脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 验证环境参数
validate_environment() {
    if [ "$ENVIRONMENT" != "test" ] && [ "$ENVIRONMENT" != "prod" ]; then
        echo -e "${RED}错误: 无效的环境 '$ENVIRONMENT'${NC}"
        echo -e "${YELLOW}支持的环境: test, prod${NC}"
        exit 1
    fi
}

# 切换到terraform目录
cd "$(dirname "$0")/../.."

# 执行命令
case $COMMAND in
    "init")
        validate_environment
        echo -e "${BLUE}初始化 $ENVIRONMENT 环境...${NC}"
        
        # 创建工作空间（如果不存在）
        terraform workspace new $ENVIRONMENT 2>/dev/null || terraform workspace select $ENVIRONMENT
        
        # 初始化
        terraform init -backend-config="environments/$ENVIRONMENT/backend.tf"
        
        echo -e "${GREEN}✅ $ENVIRONMENT 环境初始化完成${NC}"
        ;;
        
    "plan")
        validate_environment
        echo -e "${BLUE}生成 $ENVIRONMENT 环境执行计划...${NC}"
        
        terraform workspace select $ENVIRONMENT
        terraform plan -var-file="environments/$ENVIRONMENT/terraform.tfvars"
        ;;
        
    "apply")
        validate_environment
        echo -e "${BLUE}部署 $ENVIRONMENT 环境...${NC}"
        
        terraform workspace select $ENVIRONMENT
        terraform apply -var-file="environments/$ENVIRONMENT/terraform.tfvars"
        
        echo -e "${GREEN}✅ $ENVIRONMENT 环境部署完成${NC}"
        ;;
        
    "destroy")
        validate_environment
        echo -e "${YELLOW}⚠️  准备销毁 $ENVIRONMENT 环境的所有资源${NC}"
        echo -e "${RED}这个操作不可逆！${NC}"
        read -p "确认继续？(输入 'yes' 确认): " confirm
        
        if [ "$confirm" = "yes" ]; then
            terraform workspace select $ENVIRONMENT
            terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars"
            echo -e "${GREEN}✅ $ENVIRONMENT 环境资源已销毁${NC}"
        else
            echo -e "${YELLOW}操作已取消${NC}"
        fi
        ;;
        
    "switch")
        validate_environment
        echo -e "${BLUE}切换到 $ENVIRONMENT 环境...${NC}"
        
        terraform workspace select $ENVIRONMENT
        echo -e "${GREEN}✅ 已切换到 $ENVIRONMENT 环境${NC}"
        ;;
        
    "list")
        echo -e "${BLUE}可用的环境:${NC}"
        terraform workspace list
        
        echo ""
        echo -e "${BLUE}当前环境:${NC}"
        terraform workspace show
        ;;
        
    "status")
        echo -e "${BLUE}当前环境状态:${NC}"
        echo "工作空间: $(terraform workspace show)"
        echo ""
        
        # 显示资源状态
        if terraform state list >/dev/null 2>&1; then
            echo -e "${GREEN}已部署的资源:${NC}"
            terraform state list | head -10
            
            resource_count=$(terraform state list | wc -l)
            if [ $resource_count -gt 10 ]; then
                echo "... 还有 $((resource_count - 10)) 个资源"
            fi
        else
            echo -e "${YELLOW}未找到已部署的资源${NC}"
        fi
        ;;
        
    "help"|"-h"|"--help")
        show_help
        ;;
        
    *)
        echo -e "${RED}错误: 未知命令 '$COMMAND'${NC}"
        show_help
        exit 1
        ;;
esac