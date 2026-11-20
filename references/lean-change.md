# Lean change

Shared by every skill that writes or checks code. A change adds only the code its task
needs. Agents that generate code tend to add code the repo already has or no longer
needs; this file names those cases so a worker avoids them and a checker can show them.

## Extra code
Code the change adds is extra when it is one of these:
- **Duplicate**: a function, type or constant that does what an existing one in the repo already does. Evidence: the path of the existing one.
- **Unneeded dependency**: a new package where an existing dependency or the platform's standard library covers the need. Evidence: the existing dependency or the standard API.
- **Below the support floor**: a polyfill, fallback, feature check or version branch for a platform version the repo no longer supports (see "Support floor"). Evidence: the file and line that declares the floor, and the version that has the feature.
- **Dead code**: an export, parameter, option or branch that nothing uses or can reach, and commented-out code. Evidence: a search that finds no caller.
- **Debug leftover**: temporary logging, prints, `debugger` statements, or a TODO without an issue reference. Evidence: the line.

Only code the change adds or changes counts. Extra code that was already in the repo is
out of scope: do not remove it unless the task asks for it.

## Support floor
The oldest platform version the repo supports. Read it from what the repo declares; never
assume one:

| Platform | Where it is declared |
| --- | --- |
| Node.js | `engines.node` in `package.json`, `.nvmrc`, `.node-version`, the CI matrix |
| Browsers | `browserslist` in `package.json`, `.browserslistrc`, the `target` of the bundler or `tsconfig.json` |
| Python | `requires-python` in `pyproject.toml`, `python_requires` in `setup.cfg` or `setup.py` |
| Android | `minSdk` in `build.gradle` or `build.gradle.kts` |
| iOS / macOS | `IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET` in the Xcode project, `platforms` in `Package.swift` |
| Go / Rust / Java | the `go` line in `go.mod`, `rust-version` in `Cargo.toml`, the Java toolchain or `release` in the build file |
| Other | the README's or docs' "supported versions" or "requirements" section |

When the repo declares no floor for a platform, compatibility code for that platform is
not extra by this rule. A checker writes a NOTE that no floor is declared instead of
guessing one.

## How each role uses it
- Writing code (main agent, `ssak-worker`): before adding a helper or dependency, search the repo for an existing one. Do not add compatibility code below the floor.
- Verifying (`ssak-verifier`): extra code with evidence is a FAIL. Without evidence, it is a NOTE.
- Reviewing (`ssak-review`): extra code with evidence is a Medium finding. A new dependency with a known vulnerability or license problem keeps its own, higher severity.
