# Gallery SAML application

One new Entra gallery application, its enterprise principal, Entra-generated SAML
signing certificate and explicit user/group role assignments. No application
password or certificate private key is generated locally. The caller supplies
`display_name`, exact gallery `template_name`, stable `owners`,
`service_provider = { entity_id = "https://...", acs_url = "https://...", start_url = "https://..." }`
and `assignments = { operator = { principal_object_id = "<Entra-object-id>", role_name = "User" } }`.

The gallery template owns default claims, app roles and API scopes; the latter
two are explicitly ignored by the registration resource so later plans do not
remove template-created definitions. Check its NameID mapping against the
service provider's provisioned username before enabling access. Assignment is
required; an unassigned user must not get access. Duplicate display names fail.
The template creates a principal; `use_existing` deliberately brings **that new
principal** into the same module's ownership. This module does not adopt existing
registrations. Import/ownership transfer requires separate review.

The native provider generates a signing certificate with its default three-year
lifetime. It does not configure the principal's preferred signing thumbprint:
verify/activate the emitted thumbprint in Entra before downloading SAML metadata.
Certificate activation, external metadata exchange and rotation remain explicit
operator steps. Before expiry, arrange overlapping certificate trust and verify
sign-in before retiring the old certificate. No automatic rotation is claimed.

Apply using an appropriately authorised directory operator (Application
Administrator or Global Administrator), or the documented Graph application
permissions with ownership. Azure subscription Contributor alone is insufficient.

Sources: [gallery applications](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application),
[principals](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal),
[signing certificates](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal_token_signing_certificate).
