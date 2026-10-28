locals {
  name_prefix = "edgeboard-dev"

  powertools_layer_arn = "arn:aws:lambda:ap-southeast-2:017000801446:layer:AWSLambdaPowertoolsPythonV3-python313-arm64:40"

  # 三个函数共用的环境变量
  lambda_environment = {
    TABLE_NAME              = module.database.table_name
    POWERTOOLS_SERVICE_NAME = "edgeboard"
  }
}


module "database" {
  source = "../../modules/database" # 积木所在的路径（相对于当前目录）

  table_name          = local.name_prefix
  deletion_protection = false # dev 环境方便清理；prod 要设为 true
}

# 把 backend/src 打成一个 zip 包，三个函数共用（每个函数通过 handler 选择各自的入口）
data "archive_file" "backend" {
  type        = "zip"
  source_dir  = "${path.module}/../../../backend/src"
  output_path = "${path.module}/build/backend.zip"
  excludes    = ["**/__pycache__/**"]
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
