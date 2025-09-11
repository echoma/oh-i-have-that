# 主配置文件
terraform {
  required_version = ">= 1.0"
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
  }
}

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
  static_files_path   = var.static_files_path
  enable_auto_upload  = var.enable_auto_upload
  
  tags = var.common_tags
}

# 容器注册表模块
module "container_registry" {
  source = "./modules/container-registry"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  app_names = var.app_names
  
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

# SCF模块 - 为每个应用创建函数
module "scf" {
  source = "./modules/scf"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  vpc_id    = module.network.vpc_id
  subnet_id = module.network.subnet_id
  
  # 使用主要的website-api镜像
  image_uri = module.container_registry.image_uris["website-api"]
  
  tags = var.common_tags
  
  depends_on = [module.docker]
}