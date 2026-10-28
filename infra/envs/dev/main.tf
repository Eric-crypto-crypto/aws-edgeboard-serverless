locals {
  name_prefix = "edgeboard-dev"

  powertools_layer_arn = "arn:aws:lambda:ap-southeast-2:017000801446:layer:AWSLambdaPowertoolsPythonV3-python313-arm64:40"

  # 三个函数共用的环境变量
  lambda_environment = {
    TABLE_NAME              = module.database.table_name
    POWERTOOLS_SERVICE_NAME = "edgeboard"
  }

  root_domain = "edgeboard.click"
  site_domain = "dev.${local.root_domain}"

}

# 托管区由 Route 53 注册域名时自动创建，Terraform 只读取、不管理
data "aws_route53_zone" "main" {
  name = local.root_domain
}

module "database" {
  source = "../../modules/database" # 积木所在的路径（相对于当前目录）

  table_name          = local.name_prefix
  deletion_protection = false # dev 环境方便清理；prod 要设为 true
}

# 把 backend/src 打成一个 zip 包，三个函数共用（每个函数通过 handler 选择各自的入口）
data "archive_file" "backend" {
  type             = "zip"
  source_dir       = "${path.module}/../../../backend/src"
  output_path      = "${path.module}/build/backend.zip"
  output_file_mode = "0644" # 统一文件权限，保证本地和 CI 打出的 zip 完全一致
  excludes         = ["**/__pycache__/**"]
}

module "visit_function" {
  source = "../../modules/lambda_function"

  function_name    = "${local.name_prefix}-visit"
  handler          = "handlers.visit.handler"
  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256
  layers           = [local.powertools_layer_arn]
  environment      = local.lambda_environment

  dynamodb_table_arn = module.database.table_arn
  dynamodb_actions   = ["dynamodb:UpdateItem"]
}

module "list_messages_function" {
  source = "../../modules/lambda_function"

  function_name    = "${local.name_prefix}-list-messages"
  handler          = "handlers.list_messages.handler"
  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256
  layers           = [local.powertools_layer_arn]
  environment      = local.lambda_environment

  dynamodb_table_arn = module.database.table_arn
  dynamodb_actions   = ["dynamodb:Query"]
}

module "create_message_function" {
  source = "../../modules/lambda_function"

  function_name    = "${local.name_prefix}-create-message"
  handler          = "handlers.create_message.handler"
  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256
  layers           = [local.powertools_layer_arn]
  environment      = local.lambda_environment

  dynamodb_table_arn = module.database.table_arn
  dynamodb_actions   = ["dynamodb:PutItem"]
}

module "api" {
  source = "../../modules/api"

  name = "${local.name_prefix}-api"

  routes = {
    "POST /api/visit" = {
      function_name = module.visit_function.function_name
      invoke_arn    = module.visit_function.invoke_arn
    }
    "GET /api/messages" = {
      function_name = module.list_messages_function.function_name
      invoke_arn    = module.list_messages_function.invoke_arn
    }
    "POST /api/messages" = {
      function_name = module.create_message_function.function_name
      invoke_arn    = module.create_message_function.invoke_arn
    }
  }
}

module "static_site" {
  source = "../../modules/static_site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name          = local.name_prefix
  force_destroy = true # dev 环境方便清理
  api_domain    = replace(module.api.api_endpoint, "https://", "")
  domain_name   = local.site_domain
  zone_id       = data.aws_route53_zone.main.zone_id
}

module "monitoring" {
  source = "../../modules/monitoring"

  name        = local.name_prefix
  alert_email = var.alert_email

  lambda_functions = {
    "visit"          = module.visit_function.function_name
    "list-messages"  = module.list_messages_function.function_name
    "create-message" = module.create_message_function.function_name
  }

  api_id     = module.api.api_id
  table_name = module.database.table_name
}
