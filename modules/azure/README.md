# Azure Terraform modules

Reusable Azure modules live in `modules/azure/<module-name>/` within this library.

Each module contains `main.tf`, `variables.tf`, `outputs.tf`, and
a `README.md` documenting usage, inputs, outputs, and production considerations.

Deployment-specific configuration belongs in the separate bootstrap repository.
