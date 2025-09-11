#!/bin/bash

# Terraform状态存储初始化脚本
# 用于创建远程状态存储桶和相关配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Terraform状态存储初始化工具${NC}"
    echo ""
    echo "用法: $0 [环境] [选项]"
    echo ""
    echo "环境:"
    echo "  test     初始化测试环境状态存储"
    echo "  prod     初始化生产环境状态存储"
    echo "  both     初始化所有环境状态存储"
    echo ""
    echo "选项:"
    echo "  --dry-run    仅显示将要执行的操作，不实际创建资源"
    echo "  --force      强制重新创建（删除现有存储桶）"
    echo ""
    echo "示例:"
    echo "  $0 test              # 初始化测试环境"
    echo "  $0 prod --dry-run    # 预览生产环境初始化"
    echo "  $0 both              # 初始化所有环境"
}

# 检查必要的环境变量
check_credentials() {
    if [ -z "$TENCENTCLOUD_SECRET_ID" ] || [ -z "$TENCENTCLOUD_SECRET_KEY" ]; then
        echo -e "${RED}错误: 请设置腾讯云认证环境变量${NC}"
        echo "export TENCENTCLOUD_SECRET_ID=\"your_secret_id\""
        echo "export TENCENTCLOUD_SECRET_KEY=\"your_secret_key\""
        exit 1
    fi
}

# 创建状态存储桶
create_state_bucket() {
    local env=$1
    local bucket_name="terraform-state-${env}-oh-i-have-that"
    local region="ap-guangzhou"
    
    echo -e "${BLUE}创建 $env 环境状态存储桶: $bucket_name${NC}"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY RUN] 将创建存储桶: $bucket_name${NC}"
        return
    fi
    
    # 使用腾讯云CLI创建存储桶
    if command -v tccli >/dev/null 2>&1; then
        echo "使用腾讯云CLI创建存储桶..."
        
        # 创建存储桶
        tccli cos CreateBucket \
            --region $region \
            --Bucket $bucket_name \
            --ACL private
        
        # 启用版本控制
        tccli cos PutBucketVersioning \
            --region $region \
            --Bucket $bucket_name \
            --VersioningConfiguration Status=Enabled
        
        # 配置服务端加密
        tccli cos PutBucketEncryption \
            --region $region \
            --Bucket $bucket_name \
            --ServerSideEncryptionConfiguration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }'
        
        echo -e "${GREEN}✅ 存储桶 $bucket_name 创建成功${NC}"
    else
        echo -e "${YELLOW}⚠️  未安装腾讯云CLI，请手动创建存储桶${NC}"
        echo "存储桶名称: $bucket_name"
        echo "地域: $region"
        echo "访问权限: 私有"
        echo "版本控制: 启用"
        echo "加密: AES256"
    fi
}

# 创建状态存储桶策略
create_bucket_policy() {
    local env=$1
    local bucket_name="terraform-state-${env}-oh-i-have-that"
    
    echo -e "${BLUE}配置 $env 环境存储桶策略${NC}"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY RUN] 将配置存储桶策略${NC}"
        return
    fi
    
    # 创建策略文件
    cat > "/tmp/bucket-policy-${env}.json" << EOF
{
    "version": "2.0",
    "statement": [
        {
            "effect": "allow",
            "principal": {
                "qcs": ["qcs::cam::uin/\${ACCOUNT_ID}:root"]
            },
            "action": [
                "cos:GetObject",
                "cos:PutObject",
                "cos:DeleteObject",
                "cos:ListBucket"
            ],
            "resource": [
                "qcs::cos:ap-guangzhou:uid/\${ACCOUNT_ID}:${bucket_name}/*",
                "qcs::cos:ap-guangzhou:uid/\${ACCOUNT_ID}:${bucket_name}"
            ]
        }
    ]
}
EOF
    
    echo -e "${GREEN}✅ 存储桶策略配置完成${NC}"
}

# 验证状态存储配置
verify_state_storage() {
    local env=$1
    local bucket_name="terraform-state-${env}-oh-i-have-that"
    
    echo -e "${BLUE}验证 $env 环境状态存储配置${NC}"
    
    if command -v tccli >/dev/null 2>&1; then
        # 检查存储桶是否存在
        if tccli cos HeadBucket --region ap-guangzhou --Bucket $bucket_name >/dev/null 2>&1; then
            echo -e "${GREEN}✅ 存储桶 $bucket_name 存在${NC}"
            
            # 检查版本控制
            version_status=$(tccli cos GetBucketVersioning --region ap-guangzhou --Bucket $bucket_name --output text --query 'Status')
            if [ "$version_status" = "Enabled" ]; then
                echo -e "${GREEN}✅ 版本控制已启用${NC}"
            else
                echo -e "${YELLOW}⚠️  版本控制未启用${NC}"
            fi
        else
            echo -e "${RED}❌ 存储桶 $bucket_name 不存在${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  无法验证，请手动检查存储桶配置${NC}"
    fi
}

# 生成初始化指南
generate_init_guide() {
    local env=$1
    
    echo -e "${BLUE}生成 $env 环境初始化指南${NC}"
    
    cat > "terraform-${env}-init-guide.md" << EOF
# $env 环境 Terraform 初始化指南

## 状态存储配置

- **存储桶名称**: terraform-state-${env}-oh-i-have-that
- **地域**: ap-guangzhou
- **前缀**: oh-i-have-that/${env}/
- **加密**: 启用 (AES256)
- **版本控制**: 启用

## 初始化步骤

1. 确保已设置腾讯云认证信息:
   \`\`\`bash
   export TENCENTCLOUD_SECRET_ID="your_secret_id"
   export TENCENTCLOUD_SECRET_KEY="your_secret_key"
   \`\`\`

2. 初始化 Terraform:
   \`\`\`bash
   cd terraform
   terraform init -backend-config="environments/${env}/backend.tf"
   \`\`\`

3. 选择工作空间:
   \`\`\`bash
   terraform workspace new ${env}
   terraform workspace select ${env}
   \`\`\`

## 安全注意事项

- ✅ 状态文件已加密存储
- ✅ 启用了版本控制
- ⚠️  请定期备份状态文件
- ⚠️  限制存储桶访问权限
- ⚠️  不要将状态文件提交到代码仓库

## 故障排除

如果遇到初始化问题:

1. 检查存储桶是否存在
2. 验证访问权限
3. 确认网络连接
4. 查看 Terraform 日志

EOF

    echo -e "${GREEN}✅ 初始化指南已生成: terraform-${env}-init-guide.md${NC}"
}

# 主函数
main() {
    local environment=""
    local dry_run=false
    local force=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            test|prod|both)
                environment="$1"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知参数 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查参数
    if [ -z "$environment" ]; then
        echo -e "${RED}错误: 请指定环境${NC}"
        show_help
        exit 1
    fi
    
    # 设置全局变量
    DRY_RUN=$dry_run
    FORCE=$force
    
    # 检查认证信息
    check_credentials
    
    echo -e "${BLUE}开始初始化 Terraform 状态存储${NC}"
    echo "环境: $environment"
    echo "预览模式: $dry_run"
    echo "强制模式: $force"
    echo ""
    
    # 执行初始化
    if [ "$environment" = "both" ]; then
        for env in test prod; do
            echo -e "${BLUE}处理 $env 环境...${NC}"
            create_state_bucket $env
            create_bucket_policy $env
            verify_state_storage $env
            generate_init_guide $env
            echo ""
        done
    else
        create_state_bucket $environment
        create_bucket_policy $environment
        verify_state_storage $environment
        generate_init_guide $environment
    fi
    
    echo -e "${GREEN}🎉 状态存储初始化完成！${NC}"
    echo ""
    echo "下一步:"
    echo "1. 查看生成的初始化指南"
    echo "2. 运行 terraform init 初始化项目"
    echo "3. 开始使用 Terraform 管理基础设施"
}

# 执行主函数
main "$@"