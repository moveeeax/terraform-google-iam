# Run with: terraform test
#
# NOTE: `mock_provider` requires Terraform >= 1.7. That is a requirement of this
# test suite only — the module itself still supports terraform >= 1.5 as declared
# in versions.tf, and required_version is deliberately not raised for it.

mock_provider "google" {}

variables {
  project_id = "example-project"
}

run "no_bindings_creates_nothing" {
  variables {
    bindings = {}
  }

  assert {
    condition     = length(google_project_iam_member.this) == 0
    error_message = "An empty bindings map must not create any IAM resources."
  }
}

run "bindings_are_expanded_per_role_and_member" {
  variables {
    bindings = {
      "roles/storage.objectViewer" = [
        "group:developers@example.com",
        "user:alice@example.com",
      ]
      "roles/logging.viewer" = ["group:developers@example.com"]
    }
  }

  assert {
    condition     = length(google_project_iam_member.this) == 3
    error_message = "Each role/member pair must produce exactly one google_project_iam_member."
  }

  assert {
    condition     = google_project_iam_member.this["roles/logging.viewer|group:developers@example.com"].role == "roles/logging.viewer"
    error_message = "Binding keys must map to the role they were declared under."
  }

  assert {
    condition     = google_project_iam_member.this["roles/logging.viewer|group:developers@example.com"].project == "example-project"
    error_message = "Bindings must be applied to var.project_id."
  }
}

# A repeated member inside one role list is meaningless but must not blow up with an
# error about duplicate object keys inside the module.
run "duplicate_members_are_deduplicated" {
  variables {
    bindings = {
      "roles/logging.viewer" = [
        "group:developers@example.com",
        "group:developers@example.com",
      ]
    }
  }

  assert {
    condition     = length(google_project_iam_member.this) == 1
    error_message = "A member repeated within the same role must collapse to a single binding."
  }
}

## Unsafe defaults -------------------------------------------------------------

run "rejects_owner_by_default" {
  command = plan

  variables {
    bindings = {
      "roles/owner" = ["user:alice@example.com"]
    }
  }

  expect_failures = [google_project_iam_member.this]
}

run "rejects_editor_by_default" {
  command = plan

  variables {
    bindings = {
      "roles/editor" = ["user:alice@example.com"]
    }
  }

  expect_failures = [google_project_iam_member.this]
}

run "allows_primitive_roles_when_explicitly_opted_in" {
  variables {
    allow_primitive_roles = true
    bindings = {
      "roles/owner" = ["user:alice@example.com"]
    }
  }

  assert {
    condition     = google_project_iam_member.this["roles/owner|user:alice@example.com"].role == "roles/owner"
    error_message = "allow_primitive_roles = true must permit a basic role grant."
  }
}

run "viewer_is_not_treated_as_a_blocked_primitive_role" {
  variables {
    bindings = {
      "roles/viewer" = ["group:auditors@example.com"]
    }
  }

  assert {
    condition     = length(google_project_iam_member.this) == 1
    error_message = "roles/viewer is read-only and must not require allow_primitive_roles."
  }
}

run "rejects_all_users_by_default" {
  command = plan

  variables {
    bindings = {
      "roles/storage.objectViewer" = ["allUsers"]
    }
  }

  expect_failures = [google_project_iam_member.this]
}

run "rejects_all_authenticated_users_by_default" {
  command = plan

  variables {
    bindings = {
      "roles/storage.objectViewer" = ["allAuthenticatedUsers"]
    }
  }

  expect_failures = [google_project_iam_member.this]
}

run "allows_public_members_when_explicitly_opted_in" {
  variables {
    allow_public_members = true
    bindings = {
      "roles/storage.objectViewer" = ["allUsers"]
    }
  }

  assert {
    condition     = google_project_iam_member.this["roles/storage.objectViewer|allUsers"].member == "allUsers"
    error_message = "allow_public_members = true must permit a public grant."
  }
}

## Input validation ------------------------------------------------------------

run "rejects_bare_email_member" {
  command = plan

  variables {
    bindings = {
      "roles/viewer" = ["alice@example.com"]
    }
  }

  expect_failures = [var.bindings]
}

run "rejects_unknown_member_prefix" {
  command = plan

  variables {
    bindings = {
      "roles/viewer" = ["users:alice@example.com"]
    }
  }

  expect_failures = [var.bindings]
}

run "rejects_role_without_roles_prefix" {
  command = plan

  variables {
    bindings = {
      "storage.admin" = ["user:alice@example.com"]
    }
  }

  expect_failures = [var.bindings]
}

run "accepts_custom_roles_and_workload_identity_principals" {
  variables {
    bindings = {
      "projects/example-project/roles/customDeployer" = [
        "serviceAccount:app@example-project.iam.gserviceaccount.com",
        "principalSet://iam.googleapis.com/projects/1234/locations/global/workloadIdentityPools/gh/attribute.repository/acme/app",
      ]
      "organizations/123456789/roles/customAuditor" = ["domain:example.com"]
    }
  }

  assert {
    condition     = length(google_project_iam_member.this) == 3
    error_message = "Custom roles and workload identity principals must be accepted."
  }
}
