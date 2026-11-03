output "state_bucket_name" {
  description = "Name of the Terraform remote state bucket, used by backend configs"
  value       = aws_s3_bucket.tfstate.bucket
}
