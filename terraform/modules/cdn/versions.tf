# ------------------------------------------------------------------------------
# CDN Module Version Constraints
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.18.0"
      configuration_aliases = [
        aws.us_east_1
      ]
    }
  }
}

