# ELV1/ELV2 Pre-ELV3 Governance Checklist

Status: OWNER ACTION REQUIRED
Observed baseline: `main@f05b1e558a93b40928429ca86d91f4daa0cf4ef0`
Hardening branch: `feat/flutter-elv12-pre-elv3-hardening`

## Observed state

The post-merge audit observed `main` with branch protection disabled and no required status checks enforced by repository settings. The connected GitHub integration available to this work can read protection/ruleset state but cannot modify repository administration settings.

This document is therefore the explicit external-governance handoff required by H2. It does **not** claim that protection is already enabled.

## Required owner settings for `main`

Before ELV3 implementation begins, verify all of the following in GitHub repository settings:

- [ ] Require a pull request before merging.
- [ ] Require `Flutter Local Foundation` to pass before merging.
- [ ] Require the branch to be up to date / merge the exact reviewed head.
- [ ] Require conversation resolution when review threads exist.
- [ ] Block force pushes to `main`.
- [ ] Block deletion of `main`.
- [ ] Review any administrator bypass and keep it only if intentionally required for repository recovery.

## Engineering gate

```text
final feature SHA
  -> exact-SHA CI GREEN
  -> review
  -> merge
  -> post-merge main CI GREEN
```

No documentation-only commit may be added after the accepted exact-SHA gate without rerunning CI on the new SHA.

## Closure rule

H2 is complete only after the repository owner confirms that the settings above are enabled (or an equivalent repository ruleset enforces them). Until then, code hardening may merge, but ELV3 implementation entry remains governance-pending.
