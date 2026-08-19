# SDD ledger — plan: docs/superpowers/plans/2026-08-19-google-login-safari-redirect.md

MERGE_BASE: 7175c08d407fb0267320b562a71ffd79709e46c7

Task 1: minor (deferred): implementer report cites non-existent "Context section" — code is correct, citation is fabricated
Task 1: fix round 1/5 (1 addressed, 0 open — error.localizedDescription leak fixed; commits 87c384a..32357c6)
Task 1: complete (commits 7175c08..32357c6, review clean)

Task 2: complete — evidence captured, root cause identified
  Root cause: accounts.youtube.com not in isGoogleDomain() allowlist.
  NavigationPolicy.decide() returned .openInSafari → app explicitly opened Safari.
  Not a +2 hack failure. None of planned branches (3A/3B/3C) matched.
  Safari log confirmed: webpageURL = https://accounts.youtube.com/accounts/SetSID

Task 3: complete (root cause simpler than planned branches)
  Fix: added youtube.com + subdomains to isGoogleDomain() in NavigationPolicy.swift
  +2 hack auto-applies via allowPolicy(for:)
  Tests: testAllowsYouTubeDomainsInOAuthFlow, testRejectsLookalikeDomains — both pass
  verify.sh: pass
