# Global Pi instructions

## Herdr environment detection

When asked to control Herdr panes or agents, select the interface from
the current process environment:

- If HC_TERMINAL_ID and HC_TERMINAL_SOCKET are nonempty, use desktop
  Herdr. Read `hc --skill` for running and coordinating agents, and
  `herdr-app --skill` for arranging panes.
- Otherwise, if HERDR_ENV=1, use legacy Herdr. Read `herdr --skill`.
- If neither matches, explain that the managed environment is not
  identified before attempting control.

Check desktop identifiers first. Missing HERDR_ENV does not mean the
process is outside desktop Herdr. Use the matching interface and its
inherited session context; never fabricate environment variables or
fall back to a different session.
