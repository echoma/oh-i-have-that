# Oh I Have That Makefile

.PHONY: help init plan apply destroy clean build-frontend build-backend docker-build docker-push deploy-all dev-frontend dev-backend

# 默认目标
help: ## 显示帮助信息
	@echo "🚀 Oh I Have That 部署工具"
	@echo ""
	@echo "📋 可用命令:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# 🔒 状态管理
init-state: ## 初始化远程状态存储
	@echo "🔒 初始化远程状态存储..."
	./scripts/init-state-storage.sh both

init-state-test: ## 初始化测试环境状态存储
	@echo "🔒 初始化测试环境状态存储..."
	./scripts/init-state-storage.sh test

init-state-prod: ## 初始化生产环境状态存储
	@echo "🔒 初始化生产环境状态存储..."
	./scripts/init-state-storage.sh prod

backup-state: ## 备份当前状态文件
	@echo "💾 备份状态文件..."
	@mkdir -p state-backups
	cd infrastructure && terraform state pull > ../state-backups/backup-$(shell date +%Y%m%d-%H%M%S).tfstate
	@echo "✅ 状态文件已备份到 state-backups/"

# 🏗️ Terraform操作 (默认生产环境)
init: ## 初始化Terraform (生产环境)
	@echo "🔧 初始化生产环境..."
	cd infrastructure && ../scripts/workspace.sh init prod

plan: ## 查看Terraform执行计划 (生产环境)
	@echo "📋 生成生产环境执行计划..."
	cd infrastructure && ../scripts/workspace.sh plan prod

apply: ## 应用Terraform配置 (生产环境)
	@echo "🚀 部署生产环境..."
	cd infrastructure && ../scripts/workspace.sh apply prod

destroy: ## 销毁所有资源 (生产环境)
	@echo "💥 销毁生产环境资源..."
	cd infrastructure && ../scripts/workspace.sh destroy prod

# 🧪 测试环境操作
init-test: ## 初始化测试环境
	@echo "🔧 初始化测试环境..."
	cd infrastructure && ../scripts/workspace.sh init test

plan-test: ## 查看测试环境执行计划
	@echo "📋 生成测试环境执行计划..."
	cd infrastructure && ../scripts/workspace.sh plan test

apply-test: ## 部署测试环境
	@echo "🚀 部署测试环境..."
	cd infrastructure && ../scripts/workspace.sh apply test

destroy-test: ## 销毁测试环境资源
	@echo "💥 销毁测试环境资源..."
	cd infrastructure && ../scripts/workspace.sh destroy test

# 🔄 环境管理
switch-prod: ## 切换到生产环境
	@echo "🔄 切换到生产环境..."
	cd infrastructure && ../scripts/workspace.sh switch prod

switch-test: ## 切换到测试环境
	@echo "🔄 切换到测试环境..."
	cd infrastructure && ../scripts/workspace.sh switch test

list-envs: ## 列出所有环境
	@echo "📋 环境列表:"
	cd infrastructure && ../scripts/workspace.sh list

env-status: ## 显示当前环境状态
	@echo "📊 当前环境状态:"
	cd infrastructure && ../scripts/workspace.sh status

# 🎨 前端操作
build-frontend: ## 构建前端静态文件
	@echo "🎨 构建前端资源..."
	cd frontend && npm install && npm run build

dev-frontend: ## 启动前端开发服务器
	@echo "🎨 启动前端开发服务器..."
	cd frontend && npm install && npm run dev

# 📦 依赖管理
download-deps: ## 下载Go依赖包
	@echo "📦 下载Go依赖包..."
	./scripts/download-deps.sh

fix-deps: ## 修复Go依赖问题
	@echo "🔧 修复Go依赖问题..."
	@echo "设置Go代理..."
	@export GOPROXY=https://goproxy.cn,direct && \
	export GOSUMDB=sum.golang.google.cn && \
	for app in website-api user-service notification-service; do \
		echo "修复 $$app 依赖..."; \
		cd backend/$$app && go clean -modcache && go mod tidy && go mod download && cd ../..; \
	done

# ⚙️ 后端操作
build-backend: download-deps ## 构建所有后端Go应用
	@echo "⚙️ 构建后端应用..."
	@for app in website-api user-service notification-service; do \
		echo "构建 $$app..."; \
		cd backend/$$app && go mod tidy && go build -o main . && cd ../..; \
	done

dev-backend: ## 启动后端开发服务器(website-api)
	@echo "⚙️ 启动后端开发服务器..."
	cd backend/website-api && go run main.go

test-backend: ## 运行后端测试
	@echo "🧪 运行后端测试..."
	@for app in website-api user-service notification-service; do \
		echo "测试 $$app..."; \
		cd backend/$$app && go test ./... && cd ../..; \
	done

# 🐳 Docker操作
docker-build: ## 构建所有Docker镜像
	@echo "🐳 构建Docker镜像..."
	@for app in website-api user-service notification-service; do \
		echo "构建 $$app 镜像..."; \
		cd backend/$$app && docker build -t $$app:latest . && cd ../..; \
	done

docker-push: ## 推送Docker镜像到注册表
	@echo "📤 推送Docker镜像..."
	@echo "请先配置镜像仓库地址"

# 🚀 完整部署流程
deploy-all: init build-frontend build-backend apply ## 完整部署流程 (生产环境)
	@echo "✅ 生产环境部署完成！"

deploy-all-test: init-test build-frontend build-backend apply-test ## 完整部署流程 (测试环境)
	@echo "✅ 测试环境部署完成！"

deploy-frontend: build-frontend ## 仅部署前端 (生产环境)
	@echo "🎨 部署前端资源到生产环境..."
	cd infrastructure && terraform workspace select prod && terraform apply -target=module.cos -var-file=environments/prod/terraform.tfvars

deploy-frontend-test: build-frontend ## 仅部署前端 (测试环境)
	@echo "🎨 部署前端资源到测试环境..."
	cd infrastructure && terraform workspace select test && terraform apply -target=module.cos -var-file=environments/test/terraform.tfvars

deploy-backend: build-backend docker-build ## 仅部署后端 (生产环境)
	@echo "⚙️ 部署后端服务到生产环境..."
	cd infrastructure && terraform workspace select prod && terraform apply -target=module.scf -var-file=environments/prod/terraform.tfvars

deploy-backend-test: build-backend docker-build ## 仅部署后端 (测试环境)
	@echo "⚙️ 部署后端服务到测试环境..."
	cd infrastructure && terraform workspace select test && terraform apply -target=module.scf -var-file=environments/test/terraform.tfvars

# 🧹 清理操作
clean: ## 清理构建文件
	@echo "🧹 清理构建文件..."
	@for app in website-api user-service notification-service; do \
		rm -f backend/$$app/main; \
	done
	rm -rf frontend/dist
	rm -rf frontend/node_modules
	cd infrastructure && rm -rf .terraform terraform.tfstate*

clean-state-backups: ## 清理状态备份文件
	@echo "🧹 清理状态备份文件..."
	rm -rf state-backups/

# 📊 项目状态
status: ## 查看项目状态
	@echo "📊 项目状态检查..."
	@echo "前端状态:"
	@if [ -d "frontend/node_modules" ]; then echo "  ✅ 前端依赖已安装"; else echo "  ❌ 前端依赖未安装"; fi
	@if [ -d "frontend/dist" ]; then echo "  ✅ 前端已构建"; else echo "  ❌ 前端未构建"; fi
	@echo "后端状态:"
	@for app in website-api user-service notification-service; do \
		if [ -f "backend/$$app/main" ]; then echo "  ✅ $$app 已构建"; else echo "  ❌ $$app 未构建"; fi; \
	done
	@echo "基础设施状态:"
	@if [ -d "infrastructure/.terraform" ]; then echo "  ✅ Terraform已初始化"; else echo "  ❌ Terraform未初始化"; fi
	@echo "状态备份:"
	@if [ -d "state-backups" ]; then echo "  ✅ 存在状态备份 ($(shell ls state-backups/ 2>/dev/null | wc -l) 个文件)"; else echo "  ❌ 无状态备份"; fi

# 🔧 开发工具
fmt: ## 格式化代码
	@echo "🔧 格式化代码..."
	cd terraform && terraform fmt -recursive
	@for app in website-api user-service notification-service; do \
		cd backend/$$app && go fmt ./... && cd ../..; \
	done

validate: ## 验证配置
	@echo "✅ 验证配置..."
	cd terraform && terraform validate
	@for app in website-api user-service notification-service; do \
		cd backend/$$app && go vet ./... && cd ../..; \
	done

security-check: ## 安全检查
	@echo "🔒 执行安全检查..."
	@echo "检查敏感文件是否被忽略..."
	@if [ -f "infrastructure/terraform.tfvars" ]; then echo "  ⚠️  发现 terraform.tfvars 文件，请确保已添加到 .gitignore"; fi
	@if [ -f ".env" ]; then echo "  ⚠️  发现 .env 文件，请确保已添加到 .gitignore"; fi
	@if [ -d "infrastructure/.terraform" ]; then echo "  ✅ .terraform 目录存在，请确保已添加到 .gitignore"; fi
	@echo "检查状态文件..."
	@if find . -name "*.tfstate*" -not -path "./state-backups/*" | grep -q .; then echo "  ⚠️  发现状态文件，请确保使用远程存储"; else echo "  ✅ 未发现本地状态文件"; fi