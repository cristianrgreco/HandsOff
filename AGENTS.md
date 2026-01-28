- After completing an app code change, run `scripts/test.sh` and then `scripts/build_and_run.sh` to build and relaunch the app.
  - This is not required for test-only runs or documentation-only changes.
  - Running `scripts/build_and_run.sh` requires sandbox escalation as re-launching the app runs a `killall` command, ask for it.
- Running git commands requires sandbox escalation, ask for it.

Testing process:
- Primary test run: `scripts/test.sh` (runs unit tests + UI tests via the HandsOffTests scheme).
- When running `scripts/test.sh` via tool calls, set a longer timeout (e.g., 5-10 minutes) to avoid premature termination.
- Coverage report: `xcrun xccov view --report --json .build/Logs/Test/<latest>.xcresult` (or `--report` for human-readable output).
- If tests fail, capture the failing xcresult path from the `scripts/test.sh` output and use it for coverage/logs.
