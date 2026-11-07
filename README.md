# terraform-google-iam

Terraform module that manages [Google Cloud](https://cloud.google.com/)
project-level IAM member bindings (`google_project_iam_member`). It takes a map
of role to members and grants each member the role using non-authoritative
member bindings.

Non-authoritative means this module only ever **adds** the grants you list. It
never removes bindings it does not manage, so it cannot strip out existing
members the way `google_project_iam_policy` or `google_project_iam_binding`
would.

## Usage

```hcl
module "iam" {
  source = "github.com/moveeeax/terraform-google-iam?ref=v1.0.0"

  project_id = var.project_id

  bindings = {
    "roles/logging.viewer"       = ["group:team@example.com"]
    "roles/storage.objectViewer" = ["user:alice@example.com"]
  }
}
```

Grants that should only hold under a condition, such as a time-bound
break-glass grant or access limited to one bucket prefix, go in
`conditional_bindings`:

```hcl
module "iam" {
  source = "github.com/moveeeax/terraform-google-iam?ref=v1.0.0"

  project_id = var.project_id

  conditional_bindings = [
    {
      role        = "roles/compute.instanceAdmin.v1"
      members     = ["user:oncall@example.com"]
      title       = "break-glass-2026-11"
      description = "Incident access, expires at the end of November."
      expression  = "request.time < timestamp(\"2026-12-01T00:00:00Z\")"
    },
    {
      role       = "roles/storage.objectViewer"
      members    = ["group:analysts@example.com"]
      title      = "reports-prefix"
      expression = "resource.name.startsWith(\"projects/_/buckets/exports/objects/reports/\")"
    },
  ]
}
```

Each member becomes its own `google_project_iam_member` with a `condition`
block, keyed by `role|member|title`. A `role` and `title` pair may appear only
once, but one member can hold the same role under several differently titled
conditions. The expression is passed to IAM as written; the module checks only
that it is not empty, so CEL errors surface at apply time.

A runnable example lives in [`examples/basic`](examples/basic).

## Safety guardrails

Two classes of grant are rejected at plan time unless you opt in explicitly,
in `bindings` and `conditional_bindings` alike. A condition does not lift
either guardrail.
Each has a dedicated boolean variable so the override is visible in code review
rather than buried in a role string.

| Rejected by default | Why | Override |
|---------------------|-----|----------|
| `roles/owner`, `roles/editor` | Basic ("primitive") roles grant broad access across every service. `roles/editor` can modify nearly all resources; `roles/owner` can additionally rewrite IAM policy, making privilege escalation trivial. | `allow_primitive_roles = true` |
| `allUsers`, `allAuthenticatedUsers` | A project-level grant to either member exposes the permission publicly — `allUsers` to anyone on the internet, `allAuthenticatedUsers` to any Google account anywhere. | `allow_public_members = true` |

`roles/viewer` is **not** blocked: it is read-only and cannot escalate
privilege. It is still a basic role, so prefer a predefined or custom role where
one fits.

Roles and members are also validated for shape, so a typo such as a bare
`alice@example.com` (missing the `user:` prefix) fails during `terraform plan`
instead of surfacing as an opaque API error during `terraform apply`.

## Tests

```sh
terraform test
```

The suite runs against a mocked provider, so it needs no Google Cloud
credentials and no network access. `terraform test` with `mock_provider`
requires Terraform >= 1.7; the module itself still supports >= 1.5.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name                    | Description                                                              | Type                | Default | Required |
|-------------------------|--------------------------------------------------------------------------|---------------------|---------|:--------:|
| `project_id`            | ID of the project to which the bindings are applied.                     | `string`            | n/a     |   yes    |
| `bindings`              | Map of role to list of members.                                          | `map(list(string))` | `{}`    |    no    |
| `conditional_bindings`  | Grants with an IAM condition: `role`, `members`, `title`, `expression`, optional `description`. | `list(object)` | `[]` | no |
| `allow_primitive_roles` | Permit granting the basic roles `roles/owner` and `roles/editor`.        | `bool`              | `false` |    no    |
| `allow_public_members`  | Permit granting to `allUsers` / `allAuthenticatedUsers`.                 | `bool`              | `false` |    no    |

## Outputs

| Name         | Description                                       |
|--------------|---------------------------------------------------|
| `member_ids` | Identifiers of the created member bindings.       |
| `etags`      | Etags of the IAM policies for the bindings.       |
| `conditional_member_ids` | Identifiers of the conditional member bindings, keyed by `role\|member\|title`. |
| `conditional_etags`      | Etags of the IAM policies for the conditional bindings.                      |

## License

[MIT](LICENSE)
