# `dns` module

Create a public Route53 zone for a fqdn and generate a wildcard certificate for it.

**Note:** A wildcard certificate is only generated if the fqdn is not a top level domain e.g.
  - login.walletconnect.com will generate a wildcard
  - walletconnect.com will not generate a wildcard

## Variables

- `zone_domain`
  The domain for the zone, e.g. `login.walletconnect.com`, this will result in the certificate of `*.login.walletconnect.com`

## Outputs

- `zone_arn`
  The ARN for the created zone so that you can add other records to the zone

- `zone_id`
  The ID for the created zone so that you can add other records to the zone

- `certificate_arn`
  The ARN for the generated certificate so that is can be passed to other services e.g. ELBs
