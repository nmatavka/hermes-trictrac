# Hermes Bluesky Unified SDK

`hermes_bluesky` is a new root Elixir SDK that stitches together the protocol, client, media, OAuth, and realtime Bluesky pieces found in this workspace.

## Highlights

- Unified `Hermes.Bluesky.Session` for app-password and OAuth usage
- High-level posting, social, profile, search, notification, admin, repo, and chat helpers
- Rich text builder plus automatic link/hashtag facet extraction
- Blob upload helpers for Bluesky image embeds
- Phoenix-facing OAuth/conn/LiveView helpers
- Generic Jetstream websocket producer with normalized events
- Explicit upstream provenance in code and `UPSTREAMS.md`

## Quick Start

```elixir
{:ok, session} =
  Hermes.Bluesky.login("alice.bsky.social", "app-password")

{:ok, post, session} =
  Hermes.Bluesky.post(session, "Hello from Hermes #elixir")

{:ok, timeline, session} =
  Hermes.Bluesky.get_timeline(session, limit: 20)
```

## OAuth

Mount [Hermes.Bluesky.Phoenix.OAuthPlug](./lib/hermes/bluesky/phoenix/oauth_plug.ex) under a Plug or Phoenix router and use the helpers in `Hermes.Bluesky.Phoenix.Conn` and `Hermes.Bluesky.Phoenix.LiveView`.
