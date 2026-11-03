locals {
  name_prefix = "edgeboard-dev"

  powertools_layer_arn = "arn:aws:lambda:ap-southeast-2:017000801446:layer:AWSLambdaPowertoolsPythonV3-python313-arm64:40"

  # Environment variables shared by all three functions
  lambda_environment = {
    TABLE_NAME              = module.database.table_name
    POWERTOOLS_SERVICE_NAME = "edgeboard"
  }

  root_domain = "edgeboard.click"
  site_domain = "dev.${local.root_domain}"

}

# The hosted zone was created by Route 53 domain registration; Terraform only reads it
data "aws_route53_zone" "main" {
  name = local.root_domain
}

module "database" {
  source = "../../modules/database" # Module path, relative to this directory

  table_name          = local.name_prefix
  deletion_protection = false # Easy cleanup in dev; set to true in prod
}

# Package backend/src into one zip shared by all three functions (each picks its own handler)
data "archive_file" "backend" {
  type             = "zip"
  source_dir       = "${path.module}/../../../backend/src"
  output_path      = "${path.module}/build/backend.zip"
  output_file_mode = "0644" # Fixed file mode so local and CI builds produce identical zips
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
  force_destroy = true # Easy cleanup in dev
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
