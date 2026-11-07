terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "iam" {
  source = "../.."

  project_id = var.project_id

  bindings = {
    "roles/viewer" = [
      "group:developers@example.com",
    ]
    "roles/storage.admin" = [
      "serviceAccount:app@${var.project_id}.iam.gserviceaccount.com",
    ]
  }

  # Time-bound grant: IAM stops honouring it once the condition is false, but
  # the binding itself stays in the policy until it is removed here.
  conditional_bindings = [
    {
      role        = "roles/logging.viewer"
      members     = ["group:oncall@example.com"]
      title       = "incident-access"
      description = "Temporary log access for an incident."
      expression  = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
    },
  ]
}

variable "project_id" {
  description = "Project ID to apply the example IAM bindings to."
  type        = string
}

variable "region" {
  description = "Region for the google provider."
  type        = string
  default     = "us-central1"
}

output "member_ids" {
  value = module.iam.member_ids
}
