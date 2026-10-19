# CI support

`linear_issue.py` preserves the read-only OAuth validator from
`library-bin-placeholder/ops-shared` at commit
`2fbf389284d6cd3e8d13c59ccda19efe9c21c661` (formerly
`ai-platform-portfolio/ops-shared`). It is vendored here because the legacy shared
workflow hardcodes its former repository location.

The `linear-issue-required` workflow needs the existing `LINEAR_CLIENT_ID` and
`LINEAR_CLIENT_SECRET` Actions secrets to be accessible to this repository.
Missing credentials fail the check; they are never replaced with static tokens.
