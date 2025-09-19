#!/bin/bash

# Oh I Have That 用户管理工具 - Shell版本
# 轻量级的用户管理脚本，适用于简单的运维场景

set -e

# 配置
USER_FILE="auth/users.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查环境变量
check_env() {
    local missing_vars=()
    
    [ -z "$COS_DATA_BUCKET" ] && missing_vars+=("COS_DATA_BUCKET")
    [ -z "$COS_REGION" ] && missing_vars+=("COS_REGION")
    [ -z "$COS_SECRET_ID" ] && missing_vars+=("COS_SECRET_ID")
    [ -z "$COS_SECRET_KEY" ] && missing_vars+=("COS_SECRET_KEY")
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "缺少必要的环境变量: ${missing_vars[*]}"
        echo ""
        echo "请设置以下环境变量:"
        for var in "${missing_vars[@]}"; do
            echo "  export $var='your-value'"
        done
        echo ""
        echo "💡 提示: 可以创建 .env 文件并运行 'source .env'"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少必要的依赖: ${missing_deps[*]}"
        echo ""
        echo "请安装缺少的依赖:"
        echo "  # Ubuntu/Debian:"
        echo "  sudo apt-get install ${missing_deps[*]}"
        echo ""
        echo "  # macOS:"
        echo "  brew install ${missing_deps[*]}"
        exit 1
    fi
}

# 生成SHA256哈希
hash_password() {
    local password="$1"
    echo -n "$password" | shasum -a 256 | cut -d' ' -f1
}

# 生成用户ID
generate_user_id() {
    local email="$1"
    echo "$email" | cut -d'@' -f1
}

# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# COS API调用
cos_api_call() {
    local method="$1"
    local key="$2"
    local data="$3"
    
    local bucket="$COS_DATA_BUCKET"
    local region="$COS_REGION"
    local secret_id="$COS_SECRET_ID"
    local secret_key="$COS_SECRET_KEY"
    
    local host="${bucket}.cos.${region}.myqcloud.com"
    local url="https://${host}/${key}"
    
    # 简化的签名（生产环境应使用完整的COS签名算法）
    local timestamp=$(date +%s)
    local auth="q-sign-algorithm=sha1&q-ak=${secret_id}&q-sign-time=${timestamp};$((timestamp+3600))&q-key-time=${timestamp};$((timestamp+3600))&q-header-list=host&q-url-param-list=&q-signature=placeholder"
    
    case "$method" in
        "GET")
            curl -s -X GET \
                -H "Host: $host" \
                -H "Authorization: $auth" \
                "$url"
            ;;
        "PUT")
            curl -s -X PUT \
                -H "Host: $host" \
                -H "Authorization: $auth" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url"
            ;;
    esac
}

# 从COS加载用户数据
load_users() {
    log_info "从COS加载用户数据..."
    
    local response
    response=$(cos_api_call "GET" "$USER_FILE" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response"
    else
        # 如果文件不存在或加载失败，返回空数组
        echo "[]"
    fi
}

# 保存用户数据到COS
save_users() {
    local users_json="$1"
    
    log_info "保存用户数据到COS..."
    
    local response
    response=$(cos_api_call "PUT" "$USER_FILE" "$users_json")
    
    if [ $? -eq 0 ]; then
        log_success "用户数据保存成功"
    else
        log_error "保存用户数据失败"
        exit 1
    fi
}

# 初始化用户文件
init_users() {
    log_info "初始化用户数据文件..."
    
    local users
    users=$(load_users)
    
    local user_count
    user_count=$(echo "$users" | jq '. | length')
    
    if [ "$user_count" -gt 0 ]; then
        log_info "用户数据文件已存在，包含 $user_count 个用户"
        return
    fi
    
    # 创建空的用户文件
    save_users "[]"
    log_success "用户数据文件初始化成功"
}

# 列出用户
list_users() {
    local users
    users=$(load_users)
    
    local user_count
    user_count=$(echo "$users" | jq '. | length')
    
    if [ "$user_count" -eq 0 ]; then
        log_info "暂无用户数据"
        return
    fi
    
    # 打印表头
    printf "%-15s %-25s %-10s %-15s %-8s %-20s\n" "ID" "邮箱" "角色" "姓名" "状态" "创建时间"
    printf "%s\n" "$(printf '%.0s-' {1..95})"
    
    # 打印用户信息
    echo "$users" | jq -r '.[] | [.id, .email, .role, .name, (if .active then "激活" else "禁用" end), .created] | @tsv' | \
    while IFS=$'\t' read -r id email role name status created; do
        printf "%-15s %-25s %-10s %-15s %-8s %-20s\n" "$id" "$email" "$role" "$name" "$status" "$created"
    done
}

# 添加用户
add_user() {
    local users
    users=$(load_users)
    
    # 获取用户输入
    read -p "邮箱地址: " email
    if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        log_error "邮箱地址格式无效"
        return 1
    fi
    
    # 检查邮箱是否已存在
    local existing_user
    existing_user=$(echo "$users" | jq -r --arg email "$email" '.[] | select(.email == $email) | .email')
    if [ -n "$existing_user" ]; then
        log_error "邮箱地址已存在"
        return 1
    fi
    
    read -p "用户姓名: " name
    if [ -z "$name" ]; then
        log_error "用户姓名不能为空"
        return 1
    fi
    
    read -p "用户角色 (admin/user): " role
    if [[ "$role" != "admin" && "$role" != "user" ]]; then
        log_error "角色必须是 admin 或 user"
        return 1
    fi
    
    # 安全地读取密码
    read -s -p "密码: " password
    echo
    read -s -p "确认密码: " confirm_password
    echo
    
    if [ "$password" != "$confirm_password" ]; then
        log_error "两次输入的密码不一致"
        return 1
    fi
    
    if [ ${#password} -lt 6 ]; then
        log_error "密码长度至少6位"
        return 1
    fi
    
    # 创建新用户
    local user_id
    user_id=$(generate_user_id "$email")
    
    local hashed_password
    hashed_password=$(hash_password "$password")
    
    local timestamp
    timestamp=$(get_timestamp)
    
    local new_user
    new_user=$(jq -n \
        --arg id "$user_id" \
        --arg email "$email" \
        --arg password "$hashed_password" \
        --arg role "$role" \
        --arg name "$name" \
        --arg created "$timestamp" \
        --arg updated "$timestamp" \
        '{
            id: $id,
            email: $email,
            password: $password,
            role: $role,
            name: $name,
            active: true,
            created: $created,
            updated: $updated
        }')
    
    # 添加到用户列表
    local updated_users
    updated_users=$(echo "$users" | jq --argjson user "$new_user" '. + [$user]')
    
    # 保存
    save_users "$updated_users"
    log_success "用户 $email 添加成功"
}

# 显示帮助
show_help() {
    cat << EOF
Oh I Have That 用户管理工具 - Shell版本

用法: $0 <命令> [参数]

命令:
  init                    初始化用户数据文件
  list                    列出所有用户
  add                     添加新用户
  help                    显示此帮助信息

环境变量要求:
  COS_DATA_BUCKET         COS数据存储桶名称
  COS_REGION              COS区域 (如: ap-guangzhou)
  COS_SECRET_ID           腾讯云访问密钥ID
  COS_SECRET_KEY          腾讯云访问密钥Key

示例:
  $0 init                 # 初始化用户数据文件
  $0 list                 # 列出所有用户
  $0 add                  # 添加新用户

注意: 此Shell版本提供基础功能，完整功能请使用Python版本
EOF
}

# 主函数
main() {
    local command="$1"
    
    case "$command" in
        "init")
            check_env
            check_dependencies
            init_users
            ;;
        "list")
            check_env
            check_dependencies
            list_users
            ;;
        "add")
            check_env
            check_dependencies
            add_user
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            log_error "请指定命令"
            echo ""
            show_help
            exit 1
            ;;
        *)
            log_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"