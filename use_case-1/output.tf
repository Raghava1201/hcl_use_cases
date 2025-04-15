output "alb_dns_name" {
  description = "Access openproject using this ALB DNS"
  value       = aws_alb.alb.dns_name
}
