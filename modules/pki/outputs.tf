output "ca_cert_pem" {
  description = "CA certificate (public): the ALB trust store bundle and the clients' server-verification root."
  value       = tls_self_signed_cert.ca.cert_pem
}

output "ca_private_key_pem" {
  description = "CA private key. Goes straight into Secrets Manager; never a root output."
  value       = tls_private_key.ca.private_key_pem
  sensitive   = true
}

output "server_cert_pem" {
  description = "Server certificate (for the ACM import)."
  value       = tls_locally_signed_cert.server.cert_pem
}

output "server_private_key_pem" {
  description = "Server private key (for the ACM import)."
  value       = tls_private_key.server.private_key_pem
  sensitive   = true
}

output "clients" {
  description = "Per-client cert and key, keyed by CN."
  value = {
    for cn in var.client_common_names : cn => {
      cert_pem        = tls_locally_signed_cert.client[cn].cert_pem
      private_key_pem = tls_private_key.client[cn].private_key_pem
    }
  }
  sensitive = true
}
