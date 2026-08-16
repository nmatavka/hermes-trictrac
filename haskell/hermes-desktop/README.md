# Hermes Desktop

Native desktop foundation for Hermes Trictrac.

This app is designed as a Haskell desktop client over the existing Hermes rules
and session runtime:

- `local` mode launches a bundled Hermes release and talks to it as if it were a
  remote server
- `online` mode connects to an already-running Hermes server

The desktop bundle is expected to contain a support tree shaped like:

```text
bundle/
  runtime/
    hermes_trictrac/
      bin/hermes_trictrac
  support/
    ui/generated/
    images/6besh/
    trictrac_zero/
    julia/            # optional but recommended for local AI
```

The Haskell app looks for the support root in this order:

1. `--support-root=/path/to/support`
2. `HERMES_DESKTOP_SUPPORT_ROOT`
3. `../support` relative to the executable

## Current scope

The native client provides a catalog-driven lobby for all head-to-head and
multi-seat formats, the Tavli composite selector, a Phoenix Channel transport,
and a playable physical board driven exclusively by server snapshots and legal
moves. It loads the bundled catalog as a fallback and refreshes it from the
running server before the window opens.

The bundled local runtime always uses manual identity. Remote servers that
require the browser-session Bluesky OAuth flow are intentionally reported as
unavailable to the native client rather than accepting an unauthenticated join.
