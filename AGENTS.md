# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

A Crystal CLI for BambooHR time tracking. Interactive clock in/out with a live-updating
status line (session/daily/weekly totals + weekly time off), XDG-compliant YAML config, and
secure (`0o600`) credential storage.

## Commands

```bash
shards install        # install dependencies (first-time setup)
make build            # build -> ./bin/bamboohr-cli (wraps `shards build`)
make release          # optimized build: shards build --production --release --no-debug
make start            # build then run the binary
crystal run src/bamboohr_cli.cr   # run from source (NOTE: `make run` is broken, see below)

crystal spec                              # run all tests
crystal spec spec/bamboohr_api_spec.cr    # run a single spec file
crystal spec spec/bamboohr_api_spec.cr:42 # run the spec at a given line
make test-integration                     # integration tests (needs BAMBOOHR_* env vars + INTEGRATION_TEST=true)
```

The `make run` target references a non-existent file (`src/bamboohr_clock_corrected.cr`) and
will fail. The real entrypoint is `src/bamboohr_cli.cr` — use `make start` or
`crystal run src/bamboohr_cli.cr`.

## Architecture

Entry/composition order: `src/bamboohr_cli.cr` parses CLI flags (`CLIParser` with
`OptionParser`), loads config via `ConfigManager`, then constructs `CLI` and calls
`run_interactive`. The `unless PROGRAM_NAME.includes?("crystal-run-spec")` guard at the
bottom keeps the main block from executing when files are required under spec.

Three collaborating units under `src/bamboohr_cli/`:

- **`config.cr` (`ConfigManager`)** — resolves config in priority order: user file
  (`$XDG_CONFIG_HOME/bamboohr-cli/config.yml`) → system files (`$XDG_CONFIG_DIRS`, default
  `/etc/xdg`) → `BAMBOOHR_*` env vars → interactive prompts (saved back to the user file at
  `0o600`). All filesystem access goes through a `LocalFileSystem` shim implementing a
  `FileSystem`-style abstract interface, so tests can substitute an in-memory implementation.
  Interactive prompting uses `term-prompt` (masked input for the API key).

- **`api.cr` (`API`)** — thin BambooHR REST client. Host is always
  `{company_domain}.bamboohr.com` over TLS; auth is HTTP Basic with `Base64(api_key + ":x")`.
  All requests funnel through the private `make_request`. JSON responses deserialize into
  `JSON::Serializable` structs (`TimesheetEntry`, `EmployeeTimesheetEntry`, `TimeOffRequest`,
  etc.). Methods return `{Bool, T?}` tuples (success flag + payload) rather than raising;
  `get_last_response_status` / `get_last_response_body` expose the last raw response for error
  handling. Daily/weekly totals and time-off (incl. bank holidays) are computed here.

- **`cli.cr` (`CLI`)** — interactive loop and all display logic. Constructor takes an
  injectable `@io : IO` (defaults to `STDOUT`; tests pass `IO::Memory`). It caches session
  start time and daily/weekly totals to limit API calls, and spawns a background fiber
  (`start_real_time_updates`) that refreshes the inline status line every 30s while clocked
  in, coordinated with the main loop via a `Channel(Bool)`. The input loop reads single keys
  in raw mode (`STDIN.raw &.read_char`): Enter triggers clock in/out, every other key is
  ignored, and Ctrl+C (byte 3) is caught explicitly because raw mode disables `ISIG` (so the
  `Signal::INT.trap` in `bamboohr_cli.cr` does not fire during the read).

## Testing patterns

- HTTP is mocked with **WebMock** (`WebMock.allow_net_connect = false`); stub each endpoint
  explicitly. Time-dependent code is frozen with **Timecop** (`Timecop.travel`).
- Prefer the existing seams over real I/O: pass `IO::Memory` to `CLI`, stub the filesystem
  for `ConfigManager`, and assert on returned `{Bool, T?}` tuples / captured IO output.
- Shared fixtures and `create_mock_response` live in `spec/spec_helper.cr`.

## Conventions

- Commit messages follow **Conventional Commits** (`feat:`, `fix:`, etc.); versioning is
  semver — fixes are patch bumps, features minor, breaking changes major (`shard.yml`
  `version` + `CHANGELOG.md`).
