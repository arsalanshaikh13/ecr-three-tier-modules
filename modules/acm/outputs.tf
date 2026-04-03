output "app_cert_wait_certificate_arn" {
  value = aws_acm_certificate_validation.app_cert_wait.certificate_arn
}
