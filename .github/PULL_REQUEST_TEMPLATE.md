## Summary

Describe what changed and why.

## Scope

- [ ] Wallet code or tests
- [ ] Documentation
- [ ] Build, packaging, or CI
- [ ] Release tooling

## Verification

- [ ] `dart format --output=none --set-exit-if-changed lib test tool`
- [ ] `flutter analyze --no-pub`
- [ ] Relevant tests pass
- [ ] `python3 scripts/check_branding.py`
- [ ] `python3 scripts/check_free_product.py`
- [ ] `python3 scripts/generate_docs.py --check` (if generated docs changed)

## Risk

Describe user-visible risk, data-format impact, or compatibility impact. If
none, say so.

## Checklist

- [ ] No secrets, seed phrases, private keys, or signing material are included.
- [ ] Compatibility identifiers are preserved unless the change is intentional.
- [ ] Documentation and CHANGELOG are updated when needed.
- [ ] The change is linked to an issue or release note when applicable.
