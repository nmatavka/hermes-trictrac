# Upstreams

This project intentionally preserves provenance for all reused or adapted code.

## Runtime dependency

- `atex-main`
  - Role: protocol backbone, OAuth, XRPC clients, identity resolution, service auth, repo primitives
  - License: MIT
  - Integration style: local path dependency only

## Adapted code

- `proto_rune-main`
  - License: MIT
  - Reused shapes: high-level Bluesky client ergonomics, rich text builder, grouped API surfaces
  - Representative source paths:
    - `proto_rune-main/lib/proto_rune/bsky.ex`
    - `proto_rune-main/lib/proto_rune/rich_text.ex`
    - `proto_rune-main/lib/bluesky/*.ex`
    - `proto_rune-main/lib/atproto/*.ex`

- `broadcast.ex-main`
  - License: MIT
  - Reused behavior: facet extraction, blob upload flow, image embed assembly
  - Representative source paths:
    - `broadcast.ex-main/lib/broadcast.ex`
    - `broadcast.ex-main/lib/bluesky/facet.ex`

- `bsky-keyword-labeler-main`
  - License: GPL-3.0-or-later
  - Reused behavior: websocket producer lifecycle, Jetstream event ingestion strategy, Ozone label emission flow
  - Representative source paths:
    - `bsky-keyword-labeler-main/apps/bsky_labeler/lib/bsky_labeler/utils/websocket_producer.ex`
    - `bsky-keyword-labeler-main/apps/bsky_labeler/lib/bsky_labeler/pipeline/s1_bsky_producer.ex`
    - `bsky-keyword-labeler-main/apps/bsky_labeler/lib/bsky_labeler/label.ex`

## Untouched reference projects

The following directories remain untouched and serve as source/reference material only:

- `atproto-elixir-main`
- `bluesky_ex-main`
- `broadcast.ex-main`
- `bsky-keyword-labeler-main`
- `bsky_simple-master`
- `did_tools-main`
- `proto_rune-main`
