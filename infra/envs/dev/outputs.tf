output "table_name" {
  value = module.database.table_name
}

output "function_names" {
  value = {
    visit          = module.visit_function.function_name
    list_messages  = module.list_messages_function.function_name
    create_message = module.create_message_function.function_name
  }
}

output "api_endpoint" {
  value = module.api.api_endpoint
}
