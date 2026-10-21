# Contributing to Kvikkshot

Thanks for helping. Bug reports, translations and small, focused pull requests are all welcome.

## Building

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh       # build/Kvikkshot.app, signed to run locally
scripts/preflight.sh   # builds both release configurations and checks them
```

Edit `project.yml`, not the `.xcodeproj`.

## Pull requests

- Keep one change per pull request, and describe how you tested it.
- `scripts/preflight.sh` must pass.
- Kvikkshot stays offline: no network access, analytics or third-party code.
- New user-facing text goes into `Kvikkshot/Localizable.xcstrings` with English (UK), Simplified and Traditional Chinese.

By contributing you agree that your work is licensed under the [Apache License 2.0](LICENSE).
