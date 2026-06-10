# Hermes Desktop

Native desktop foundation for Hermes Trictrac.

This app is designed as a Haskell desktop shell over the existing Hermes rules
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

This scaffold currently provides:

- desktop config loading
- support tree discovery
- desktop catalog loading
- Phoenix frame codec
- snapshot decoding foundation
- local runtime launch/stop and readiness polling
- a minimal Gloss shell using the shared board assets

It is intended to be extended into the full playable desktop client.
