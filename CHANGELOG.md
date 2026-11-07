# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `conditional_bindings` input: a list of `role`, `members`, `title`,
  `expression` and optional `description` that creates
  `google_project_iam_member` grants with a `condition` block, for time-bound or
  resource-scoped access. The primitive-role and public-member guardrails apply
  to these grants as well, and roles and members get the same shape validation
  as `bindings`. Conditional grants live in a separate resource, so existing
  `bindings` keep their addresses.
- `conditional_member_ids` and `conditional_etags` outputs.

### Changed

- CI: bump actions to their current majors, pin tool versions, and restrict the
  workflow token to `contents: read`.
- CI: add Dependabot for GitHub Actions and the Terraform provider.
- Docs: pin the README usage `source` to a release tag; fix the LICENSE year.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-google-iam/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/moveeeax/terraform-google-iam/releases/tag/v1.0.0
