# Conditional bindings. Same mock provider and requirements as bindings.tftest.hcl.

mock_provider "google" {}

variables {
  project_id = "example-project"
}

run "no_conditional_bindings_by_default" {
  assert {
    condition     = length(google_project_iam_member.conditional) == 0
    error_message = "No conditional grants may be created unless conditional_bindings is set."
  }
}

run "conditional_binding_carries_condition" {
  variables {
    conditional_bindings = [
      {
        role        = "roles/storage.objectViewer"
        members     = ["group:analysts@example.com", "user:alice@example.com"]
        title       = "reports-prefix"
        description = "Only objects under reports/ in the exports bucket."
        expression  = "resource.name.startsWith(\"projects/_/buckets/exports/objects/reports/\")"
      },
    ]
  }

  assert {
    condition     = length(google_project_iam_member.conditional) == 2
    error_message = "Each member of a conditional binding must get its own grant."
  }

  assert {
    condition     = google_project_iam_member.conditional["roles/storage.objectViewer|user:alice@example.com|reports-prefix"].condition[0].title == "reports-prefix"
    error_message = "The condition title must reach the grant."
  }

  assert {
    condition     = google_project_iam_member.conditional["roles/storage.objectViewer|user:alice@example.com|reports-prefix"].condition[0].expression == "resource.name.startsWith(\"projects/_/buckets/exports/objects/reports/\")"
    error_message = "The condition expression must reach the grant unchanged."
  }

  assert {
    condition     = google_project_iam_member.conditional["roles/storage.objectViewer|user:alice@example.com|reports-prefix"].condition[0].description == "Only objects under reports/ in the exports bucket."
    error_message = "The condition description must reach the grant."
  }

  assert {
    condition     = google_project_iam_member.conditional["roles/storage.objectViewer|user:alice@example.com|reports-prefix"].project == "example-project"
    error_message = "Conditional grants must be applied to var.project_id."
  }

  assert {
    condition     = length(google_project_iam_member.this) == 0
    error_message = "Conditional bindings must not produce unconditional grants."
  }
}

run "same_role_under_two_conditions" {
  variables {
    bindings = {
      "roles/logging.viewer" = ["user:alice@example.com"]
    }
    conditional_bindings = [
      {
        role       = "roles/compute.instanceAdmin.v1"
        members    = ["user:alice@example.com"]
        title      = "break-glass"
        expression = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
      },
      {
        role       = "roles/compute.instanceAdmin.v1"
        members    = ["user:alice@example.com"]
        title      = "staging-only"
        expression = "resource.name.startsWith(\"projects/example-project/zones/us-central1-a/instances/staging-\")"
      },
    ]
  }

  assert {
    condition     = length(google_project_iam_member.conditional) == 2
    error_message = "One member may hold the same role under several distinct conditions."
  }

  assert {
    condition     = length(google_project_iam_member.this) == 1
    error_message = "Unconditional bindings must keep working next to conditional ones."
  }
}

run "conditional_duplicate_members_are_deduplicated" {
  variables {
    conditional_bindings = [
      {
        role       = "roles/logging.viewer"
        members    = ["user:alice@example.com", "user:alice@example.com"]
        title      = "temp"
        expression = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
      },
    ]
  }

  assert {
    condition     = length(google_project_iam_member.conditional) == 1
    error_message = "A member repeated within one conditional binding must collapse to a single grant."
  }
}

## Guardrails apply to conditional grants too ----------------------------------

run "rejects_conditional_owner_by_default" {
  command = plan

  variables {
    conditional_bindings = [
      {
        role       = "roles/owner"
        members    = ["user:alice@example.com"]
        title      = "break-glass"
        expression = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
      },
    ]
  }

  expect_failures = [google_project_iam_member.conditional]
}

run "rejects_conditional_public_member_by_default" {
  command = plan

  variables {
    conditional_bindings = [
      {
        role       = "roles/storage.objectViewer"
        members    = ["allUsers"]
        title      = "public-prefix"
        expression = "resource.name.startsWith(\"projects/_/buckets/site/objects/public/\")"
      },
    ]
  }

  expect_failures = [google_project_iam_member.conditional]
}

run "allows_conditional_primitive_role_when_opted_in" {
  variables {
    allow_primitive_roles = true
    conditional_bindings = [
      {
        role       = "roles/editor"
        members    = ["user:alice@example.com"]
        title      = "break-glass"
        expression = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
      },
    ]
  }

  assert {
    condition     = google_project_iam_member.conditional["roles/editor|user:alice@example.com|break-glass"].role == "roles/editor"
    error_message = "allow_primitive_roles = true must permit a conditional basic role grant."
  }
}

## Input validation ------------------------------------------------------------

run "rejects_conditional_bare_email_member" {
  command = plan

  variables {
    conditional_bindings = [
      {
        role       = "roles/viewer"
        members    = ["alice@example.com"]
        title      = "temp"
        expression = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
      },
    ]
  }

  expect_failures = [var.conditional_bindings]
}

run "rejects_conditional_malformed_role" {
  command = plan

  variables {
    conditional_bindings = [
      {
        role       = "storage.admin"
        members    = ["user:alice@example.com"]
        title      = "temp"
        expression = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
      },
    ]
  }

  expect_failures = [var.conditional_bindings]
}

run "rejects_empty_condition_expression" {
  command = plan

  variables {
    conditional_bindings = [
      {
        role       = "roles/viewer"
        members    = ["user:alice@example.com"]
        title      = "temp"
        expression = " "
      },
    ]
  }

  expect_failures = [var.conditional_bindings]
}

run "rejects_repeated_role_and_title" {
  command = plan

  variables {
    conditional_bindings = [
      {
        role       = "roles/viewer"
        members    = ["user:alice@example.com"]
        title      = "temp"
        expression = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
      },
      {
        role       = "roles/viewer"
        members    = ["user:bob@example.com"]
        title      = "temp"
        expression = "request.time < timestamp(\"2027-01-01T00:00:00Z\")"
      },
    ]
  }

  expect_failures = [var.conditional_bindings]
}
