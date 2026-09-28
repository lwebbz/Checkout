# Sandbox-only CA. Every private key here ends up in Terraform state; in
# production this module is replaced by AWS Private CA + ACM (see ADR 0002).

# --- CA ----------------------------------------------------------------------

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = var.ca_validity_hours

  # Key identifiers link each leaf to the CA that signed it; strict verifiers
  # (e.g. Python 3.13+ default contexts) reject chains without them.
  set_subject_key_id   = true
  set_authority_key_id = true

  subject {
    organization = var.organization
    common_name  = var.ca_common_name
  }

  allowed_uses = ["cert_signing", "crl_signing", "digital_signature"]
}

# --- Server ------------------------------------------------------------------

resource "tls_private_key" "server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem
  dns_names       = var.server_dns_names

  subject {
    organization = var.organization
    common_name  = var.server_dns_names[0]
  }
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem      = tls_cert_request.server.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = var.leaf_validity_hours
  early_renewal_hours   = var.early_renewal_hours
  set_subject_key_id    = true # authority key id is taken from the CA's subject key id

  allowed_uses = ["digital_signature", "key_agreement", "server_auth"]
}

# --- Clients -----------------------------------------------------------------

resource "tls_private_key" "client" {
  for_each = var.client_common_names

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "client" {
  for_each = var.client_common_names

  private_key_pem = tls_private_key.client[each.key].private_key_pem

  subject {
    organization = var.organization
    common_name  = each.key
  }
}

resource "tls_locally_signed_cert" "client" {
  for_each = var.client_common_names

  cert_request_pem      = tls_cert_request.client[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = var.leaf_validity_hours
  early_renewal_hours   = var.early_renewal_hours
  set_subject_key_id    = true

  allowed_uses = ["digital_signature", "key_agreement", "client_auth"]
}
