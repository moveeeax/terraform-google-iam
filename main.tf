locals {
  # Basic ("primitive") roles that grant broad, cross-service access. roles/viewer is
  # deliberately not in this list: it is read-only and cannot escalate privilege.
  primitive_roles = ["roles/owner", "roles/editor"]

  # Special members that make a grant public.
  public_members = ["allUsers", "allAuthenticatedUsers"]

  # Flatten role => members into individual member bindings keyed by "role|member".
  # distinct() keeps a repeated member in the same role list from producing a
  # duplicate map key, which would otherwise abort with an error pointing at module
  # internals rather than at the caller's input.
  members = merge([
    for role, members in var.bindings : {
      for member in distinct(members) : "${role}|${member}" => {
        role   = role
        member = member
      }
    }
  ]...)

  # Conditional grants, keyed by "role|member|title". The title is part of the
  # key so one member can hold the same role under several conditions.
  conditional_members = merge([
    for b in var.conditional_bindings : {
      for member in distinct(b.members) : "${b.role}|${member}|${b.title}" => {
        role        = b.role
        member      = member
        title       = b.title
        expression  = b.expression
        description = b.description
      }
    }
  ]...)
}

resource "google_project_iam_member" "this" {
  for_each = local.members

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  lifecycle {
    precondition {
      condition     = var.allow_primitive_roles || !contains(local.primitive_roles, each.value.role)
      error_message = "Refusing to grant the basic role ${each.value.role} to ${each.value.member}: it confers broad access across the whole project. Use a predefined or custom role, or set allow_primitive_roles = true to override."
    }

    precondition {
      condition     = var.allow_public_members || !contains(local.public_members, each.value.member)
      error_message = "Refusing to grant ${each.value.role} to ${each.value.member}: this makes the permission public. Set allow_public_members = true only if you intend to expose it to the internet."
    }
  }
}

# Kept as a separate resource so that adding conditions never moves the
# unconditional grants above to new addresses.
resource "google_project_iam_member" "conditional" {
  for_each = local.conditional_members

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  condition {
    title       = each.value.title
    expression  = each.value.expression
    description = each.value.description
  }

  lifecycle {
    precondition {
      condition     = var.allow_primitive_roles || !contains(local.primitive_roles, each.value.role)
      error_message = "Refusing to grant the basic role ${each.value.role} to ${each.value.member}: it confers broad access across the whole project. Use a predefined or custom role, or set allow_primitive_roles = true to override."
    }

    precondition {
      condition     = var.allow_public_members || !contains(local.public_members, each.value.member)
      error_message = "Refusing to grant ${each.value.role} to ${each.value.member}: this makes the permission public. Set allow_public_members = true only if you intend to expose it to the internet."
    }
  }
}
