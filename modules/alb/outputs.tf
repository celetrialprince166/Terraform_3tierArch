# =============================================================================
# ALB MODULE OUTPUTS
# =============================================================================
# Outputs expose the ALB DNS name and target group ARN. The DNS name is the
# public URL users access to reach the application. The target group ARN is
# used by the compute module to register EC2 instances with the ALB.
# =============================================================================

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer. This is the public URL that users access to reach your application. Example: 'myapp-alb-123456789.us-east-1.elb.amazonaws.com'. You can optionally create a Route 53 record to map a custom domain to this DNS name."
  value       = aws_lb.main.dns_name
}

output "target_group_arn" {
  description = "The ARN of the target group. This is used by the Auto Scaling Group to automatically register new EC2 instances with the load balancer when they are launched."
  value       = aws_lb_target_group.app_tg.arn
}