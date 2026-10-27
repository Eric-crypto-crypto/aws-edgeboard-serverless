locals {
  name_prefix = "edgeboard-dev"
}

module "database" {
  source = "../../modules/database" # 积木所在的路径（相对于当前目录）

  table_name          = local.name_prefix
  deletion_protection = false # dev 环境方便清理；prod 要设为 true
}
