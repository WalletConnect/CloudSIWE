# CloudSIWE

> [!IMPORTANT]
> This infrastructure is no longer used by WalletConnect

WalletConnect Self-Hosted GoTrue infrastructure and supporting files

## Terraform Infrastructure

Get yourself some AWS creds and then init your workspace:

`terraform -chdir=terraform init -var-file="vars/dev.tfvars"`

Use the dev workspace:

`terraform -chdir=terraform workspace select dev`

Now you can apply the changes:

`terraform -chdir=terraform apply  -var-file="vars/dev.tfvars"`
