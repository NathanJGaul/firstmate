# Test List: Code Mode Scout Pilot

Outer tests drive `bin/fm-spawn.sh` with a fake tmux and capture the launch line; inner tests drive the library functions.

## Outer (acceptance)

| Id | Behavior | Criterion |
| --- | --- | --- |
| O1 | no knob: claude scout and ship launch carry the `-u` form, no assignment | US1.1 |
| O2 | `scouts` plus recorded acceptance: scout launch carries the assignment | US1.2 |
| O3 | `scouts`: ship and secondmate carry the `-u` form (relaunch re-enters the same construction and is not driven separately) | US1.3 |
| O4 | `scouts` with an allowlist not listing the variable: executing the captured launch under `env -i` with a fake claude shows the variable set for the scout | US1.4 |
| O5 | caller env has the variable: ship launch executed under the real wrapper does not see it | US1.5 |
| O6 | bad value or unreadable file refuses before any record exists | US1.6 |
| O7 | `claude-permission-mode=auto` plus `scouts`: scout is off with one explanatory line | US1.7 |
| O8 | non-claude harness and raw launch unchanged | US1.8 |
| O9 | store absent, key absent, key false, store unparsable: scout off with one skip line naming the directory; spawn succeeds | US2.1 |
| O10 | acceptance recorded: no skip line | US2.2 |
| O11 | pinned worker account: the pinned root's store decides | US2.3 |
| O12 | the store bytes are unchanged after a spawn that checked it | US2.4 |
| O13 | supervision engine child does not see the variable | US3.2 |

## Inner

| Id | Behavior |
| --- | --- |
| I1 | `fm_claude_code_mode_setting` accepts `off`, `scouts`, trims whitespace, rejects others, defaults to `off` for an absent file |
| I2 | `fm_claude_code_mode_accepted` is true only for a boolean `true` |
| I3 | the knob is absent from `FM_INHERITABLE_CONFIG` |

## Live (opt-in)

L1 to L3 map to US4 and run only with a throwaway login.
