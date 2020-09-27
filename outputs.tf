output "lb_dns" {
  value = "http://${module.alb.this_lb_dns_name}"
}
