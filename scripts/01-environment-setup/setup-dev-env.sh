#!/bin/bash

# 开发环境搭建脚本
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

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/debian_version ]; then
            DISTRO="debian"
        elif [ -f /etc/redhat-release ]; then
            DISTRO="redhat"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    
    log_info "检测到操作系统: $OS"
}

# 检查工具是否已安装
check_tool() {
    local tool=$1
    local version_cmd=$2
    
    if command -v $tool &> /dev/null; then
        local version=$($version_cmd 2>&1 | head -1)
        log_success "$tool 已安装: $version"
        return 0
    else
        log_warning "$tool 未安装"
        return 1
    fi
}

# 安装Go
install_go() {
    log_info "安装Go..."
    
    case $OS in
        "macos")
            if command -v brew &> /dev/null; then
                brew install go
            else
                log_error "请先安装Homebrew或手动安装Go"
                echo "访问: https://golang.org/dl/"
                return 1
            fi
            ;;
        "linux")
            case $DISTRO in
                "debian")
                    sudo apt update
                    sudo apt install -y golang-go
                    ;;
                "redhat")
                    sudo yum install -y golang
                    ;;
                *)
                    log_error "请手动安装Go"
                    echo "访问: https://golang.org/dl/"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "请手动安装Go"
            echo "访问: https://golang.org/dl/"
            return 1
            ;;
    esac
    
    # 配置Go环境变量
    if ! grep -q "GOPATH" ~/.bashrc 2>/dev/null; then
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
        log_info "已添加Go环境变量到~/.bashrc"
    fi
    
    # 配置Go代理
    go env -w GOPROXY=https://goproxy.cn,direct
    go env -w GOSUMDB=sum.golang.google.cn
    
    log_success "Go安装完成"
}

# 安装Node.js
install_nodejs() {
    log_info "安装Node.js..."
    
    case $OS in
        "macos")
            if command -v brew &> /dev/null; then
                brew install node
            else
                log_error "请先安装Homebrew或手动安装Node.js"
                return 1
            fi
            ;;
        "linux")
            case $DISTRO in
                "debian")
                    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
                    sudo apt-get install -y nodejs
                    ;;
                "redhat")
                    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
                    sudo yum install -y nodejs
                    ;;
                *)
                    log_error "请手动安装Node.js"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "请手动安装Node.js"
            echo "访问: https://nodejs.org/"
            return 1
            ;;
    esac
    
    # 配置npm镜像
    npm config set registry https://registry.npmmirror.com
    
    log_success "Node.js安装完成"
}

# 安装Terraform
install_terraform() {
    log_info "安装Terraform..."
    
    case $OS in
        "macos")
            if command -v brew &> /dev/null; then
                brew tap hashicorp/tap
                brew install hashicorp/tap/terraform
            else
                log_error "请先安装Homebrew或手动安装Terraform"
                return 1
            fi
            ;;
        "linux")
            wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install terraform
            ;;
        *)
            log_error "请手动安装Terraform"
            echo "访问: https://www.terraform.io/downloads"
            return 1
            ;;
    esac
    
    log_success "Terraform安装完成"
}

# 安装Docker
install_docker() {
    log_info "安装Docker..."
    
    case $OS in
        "macos")
            log_info "请手动安装Docker Desktop for Mac"
            echo "访问: https://www.docker.com/products/docker-desktop"
            ;;
        "linux")
            case $DISTRO in
                "debian")
                    sudo apt-get update
                    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
                    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    sudo apt-get update
                    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
                    sudo usermod -aG docker $USER
                    ;;
                "redhat")
                    sudo yum install -y yum-utils
                    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    sudo yum install -y docker-ce docker-ce-cli containerd.io
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    sudo usermod -aG docker $USER
                    ;;
            esac
            ;;
        *)
            log_error "请手动安装Docker"
            echo "访问: https://www.docker.com/get-started"
            return 1
            ;;
    esac
    
    log_success "Docker安装完成"
}

# 安装腾讯云CLI
install_tccli() {
    log_info "安装腾讯云CLI..."
    
    if command -v pip3 &> /dev/null; then
        pip3 install tccli
    elif command -v pip &> /dev/null; then
        pip install tccli
    else
        log_error "请先安装Python和pip"
        return 1
    fi
    
    log_success "腾讯云CLI安装完成"
}

# 配置腾讯云认证
configure_tencent_cloud() {
    log_info "配置腾讯云认证..."
    
    if [ -z "$TENCENTCLOUD_SECRET_ID" ] || [ -z "$TENCENTCLOUD_SECRET_KEY" ]; then
        log_warning "请设置腾讯云认证环境变量"
        echo ""
        echo "请在~/.bashrc或~/.zshrc中添加:"
        echo "export TENCENTCLOUD_SECRET_ID=\"your-secret-id\""
        echo "export TENCENTCLOUD_SECRET_KEY=\"your-secret-key\""
        echo "export TENCENTCLOUD_REGION=\"ap-guangzhou\""
        echo ""
        echo "然后执行: source ~/.bashrc"
        return 1
    fi
    
    # 配置tccli
    if command -v tccli &> /dev/null; then
        tccli configure set secretId $TENCENTCLOUD_SECRET_ID
        tccli configure set secretKey $TENCENTCLOUD_SECRET_KEY
        tccli configure set region $TENCENTCLOUD_REGION
        log_success "腾讯云CLI配置完成"
    fi
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    local all_good=true
    
    # 检查Go
    if check_tool "go" "go version"; then
        go env GOPROXY
    else
        all_good=false
    fi
    
    # 检查Node.js
    if check_tool "node" "node --version"; then
        check_tool "npm" "npm --version"
    else
        all_good=false
    fi
    
    # 检查Terraform
    if ! check_tool "terraform" "terraform version"; then
        all_good=false
    fi
    
    # 检查Docker
    if ! check_tool "docker" "docker --version"; then
        all_good=false
    fi
    
    # 检查腾讯云CLI
    if check_tool "tccli" "tccli --version"; then
        if [ -n "$TENCENTCLOUD_SECRET_ID" ]; then
            log_success "腾讯云认证已配置"
        else
            log_warning "腾讯云认证未配置"
            all_good=false
        fi
    else
        all_good=false
    fi
    
    if $all_good; then
        log_success "所有工具安装验证通过！"
        return 0
    else
        log_error "部分工具安装失败或配置不完整"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}🚀 开发环境搭建工具${NC}"
    echo ""
    
    detect_os
    
    # 检查现有安装
    log_info "检查现有工具..."
    
    local need_go=false
    local need_node=false
    local need_terraform=false
    local need_docker=false
    local need_tccli=false
    
    check_tool "go" "go version" || need_go=true
    check_tool "node" "node --version" || need_node=true
    check_tool "terraform" "terraform version" || need_terraform=true
    check_tool "docker" "docker --version" || need_docker=true
    check_tool "tccli" "tccli --version" || need_tccli=true
    
    echo ""
    
    # 安装缺失的工具
    if $need_go; then
        install_go
    fi
    
    if $need_node; then
        install_nodejs
    fi
    
    if $need_terraform; then
        install_terraform
    fi
    
    if $need_docker; then
        install_docker
    fi
    
    if $need_tccli; then
        install_tccli
    fi
    
    # 配置腾讯云
    configure_tencent_cloud
    
    echo ""
    
    # 验证安装
    if verify_installation; then
        echo ""
        log_success "🎉 开发环境搭建完成！"
        echo ""
        echo "下一步:"
        echo "1. 重新加载shell配置: source ~/.bashrc"
        echo "2. 验证Docker权限: docker ps"
        echo "3. 开始项目开发: cd your-project && make setup"
    else
        echo ""
        log_error "❌ 开发环境搭建未完全成功"
        echo "请检查上述错误信息并手动完成安装"
    fi
}

# 执行主函数
main "$@"