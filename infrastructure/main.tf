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
  
  # 双桶配置
  static_bucket_name      = var.cos_static_bucket_name
  data_bucket_name        = var.cos_data_bucket_name
  static_files_path       = var.static_files_path
  enable_auto_upload      = var.enable_auto_upload
  app_id                  = var.app_id
  
  # 后端访问配置
  backend_allowed_origins    = var.backend_allowed_origins
  backend_service_principals = var.backend_service_principals
  
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
  enable_tcr   = var.enable_tcr
  
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

# CLB模块
module "clb" {
  source = "./modules/clb"
  
  project_name = var.project_name
  environment  = var.environment
  region      = var.region
  
  vpc_id    = module.network.vpc_id
  subnet_id = module.network.subnet_id
  
  # SCF集成
  scf_function_name = module.scf.function_name
  cos_bucket_url    = module.cos.bucket_url
  
  tags = var.common_tags
  
  depends_on = [module.scf]
}