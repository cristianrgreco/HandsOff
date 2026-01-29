App code changes:
- Offer to run `scripts/build_and_run.sh DEBUG|RELEASE` so the user can manually verify behavior.
- Then offer to run `scripts/test.sh`.
- Skip builds/tests for test-only runs or documentation-only changes.
- Add or update tests to cover new behaviors.
- For script usage details, see `README.md`.

Escalation requirements:
- `scripts/build_and_run.sh` needs sandbox escalation (it runs `killall`).
- Any git write commands needs sandbox escalation.

Project config:
- Info.plist values are likely generated from `project.yml`, so prefer updating `project.yml` for plist-related changes.

Testing process:
- Primary test run: `scripts/test.sh` (runs unit tests + UI tests via the HandsOffTests scheme).
- When running `scripts/test.sh` via tool calls, set a longer timeout (e.g., 5-10 minutes).
- Coverage report: `xcrun xccov view --report --json .build/Logs/Test/<latest>.xcresult` (or `--report` for human-readable output).
- If tests fail, capture the failing xcresult path from the `scripts/test.sh` output and use it for coverage/logs.
