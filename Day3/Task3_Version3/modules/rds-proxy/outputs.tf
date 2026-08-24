output "rds_proxy_address" {
  value = aws_db_proxy.this.endpoint
}