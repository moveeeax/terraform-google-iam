variable "project_id" {
  description = "ID of the project to which the IAM bindings are applied."
  type        = string
}

variable "bindings" {
  description = "Map of role to list of members. Each member is granted the role at the project level."
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for role in keys(var.bindings) :
      can(regex("^(roles/[A-Za-z0-9_.]+|(projects|organizations)/[^/]+/roles/[A-Za-z0-9_.]+)$", role))
    ])
    error_message = "Each key of `bindings` must be a role name: a predefined role such as \"roles/storage.admin\", or a custom role such as \"projects/<project>/roles/<id>\" or \"organizations/<org>/roles/<id>\"."
  }

  validation {
    condition = alltrue(flatten([
      for role, members in var.bindings : [
        for member in members :
        contains(["allUsers", "allAuthenticatedUsers"], member) ||
        can(regex("^(user|serviceAccount|group|domain|principal|principalSet|principalHierarchy|projectOwner|projectEditor|projectViewer|deleted):.+$", member))
      ]
    ]))
    error_message = "Every member of `bindings` must be a fully qualified IAM principal identifier, e.g. \"user:alice@example.com\", \"group:team@example.com\", \"serviceAccount:app@<project>.iam.gserviceaccount.com\", \"domain:example.com\", or a \"principal://\"/\"principalSet://\" workload identity principal. A bare email address is not a valid member."
  }
}

variable "conditional_bindings" {
  description = <<-EOT
    Role grants that only apply while an IAM condition holds, e.g. a break-glass
    grant that expires or a grant scoped to one bucket. Each entry grants `role`
    to every member in `members` with a `condition` block built from `title`,
    `expression` (CEL) and the optional `description`. The same guardrails as
    `bindings` apply. `role` and `title` together must be unique across entries,
    because they identify the grant.
  EOT
  type = list(object({
    role        = string
    members     = list(string)
    title       = string
    expression  = string
    description = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for b in var.conditional_bindings :
      can(regex("^(roles/[A-Za-z0-9_.]+|(projects|organizations)/[^/]+/roles/[A-Za-z0-9_.]+)$", b.role))
    ])
    error_message = "Each `role` in `conditional_bindings` must be a role name: a predefined role such as \"roles/storage.admin\", or a custom role such as \"projects/<project>/roles/<id>\" or \"organizations/<org>/roles/<id>\"."
  }

  validation {
    condition = alltrue(flatten([
      for b in var.conditional_bindings : [
        for member in b.members :
        contains(["allUsers", "allAuthenticatedUsers"], member) ||
        can(regex("^(user|serviceAccount|group|domain|principal|principalSet|principalHierarchy|projectOwner|projectEditor|projectViewer|deleted):.+$", member))
      ]
    ]))
    error_message = "Every member of `conditional_bindings` must be a fully qualified IAM principal identifier, e.g. \"user:alice@example.com\", \"group:team@example.com\", \"serviceAccount:app@<project>.iam.gserviceaccount.com\", \"domain:example.com\", or a \"principal://\"/\"principalSet://\" workload identity principal. A bare email address is not a valid member."
  }

  validation {
    condition     = alltrue([for b in var.conditional_bindings : trimspace(b.title) != "" && trimspace(b.expression) != ""])
    error_message = "Each entry of `conditional_bindings` needs a non-empty `title` and `expression`."
  }

  validation {
    condition = length(distinct([
      for b in var.conditional_bindings : "${b.role}|${b.title}"
    ])) == length(var.conditional_bindings)
    error_message = "Each `role` and `title` pair may appear only once in `conditional_bindings`; give conditions on the same role distinct titles."
  }
}

variable "allow_primitive_roles" {
  description = <<-EOT
    Allow the basic (primitive) roles `roles/owner` and `roles/editor` to be granted.
    These roles confer broad, poorly scoped permissions across every service in the
    project — `roles/editor` can modify nearly all resources and `roles/owner` can
    additionally change IAM policy, which makes privilege escalation trivial. Google
    recommends predefined or custom roles instead. Leave `false` unless you have
    deliberately decided a basic role is required.
  EOT
  type        = bool
  default     = false
}

variable "allow_public_members" {
  description = <<-EOT
    Allow the special members `allUsers` (anyone on the internet, unauthenticated)
    and `allAuthenticatedUsers` (any Google account, including accounts outside your
    organization) to be granted roles. A project-level grant to either member exposes
    the granted permissions publicly. Leave `false` unless you are intentionally
    publishing a resource to the internet.
  EOT
  type        = bool
  default     = false
}
