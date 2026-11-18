output "application_object_id" {
  description = "Application object ID for administration."
  value       = azuread_application.this.object_id
}

output "principal_id" {
  description = "Enterprise application object ID for administration and SAML metadata download."
  value       = azuread_service_principal.this.object_id
}

output "signing_certificate_thumbprint" {
  description = "Public signing certificate thumbprint; verify activation before exporting metadata."
  value       = azuread_service_principal_token_signing_certificate.this.thumbprint
}
