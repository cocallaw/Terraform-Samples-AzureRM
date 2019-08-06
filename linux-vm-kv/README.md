# Terraform & Azure Key Vault
Terrafrom template that refrences an existing Azure Key Vault to retrieve a secret and use in the template for configuring resources. 

This example creates a simple Unbuntu Server and the value of the SSH key is retrieved from an existing secret in Key Vault. 
The service principal that is being used for Terraform must have permissions to read secrets from the Key Vault by updating the Access Policy. 