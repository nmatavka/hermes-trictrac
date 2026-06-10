# HERMES Trictrac

Modern Phoenix 1.8 app with a React frontend over Phoenix Channels.

To start the development server:

  * Install dependencies with `mix deps.get`
  * Install frontend dependencies with `cd assets && npm install`
  * Start Phoenix with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To build production assets:

  * Run `mix assets.deploy`

To build a release:

  * Run `MIX_ENV=prod mix release`
  * Start it with `PHX_SERVER=true SECRET_KEY_BASE=$(mix phx.gen.secret) _build/prod/rel/hermes_trictrac/bin/hermes_trictrac start`

## Desktop Foundation

The repo now includes a native desktop foundation under
`/Users/nick/backgammon/haskell/hermes-desktop`.

The intended desktop bundle has two parts:

  * a Haskell desktop shell
  * a bundled Hermes release for local head-to-head play

Desktop bootstrap endpoints are available at:

  * `GET /api/desktop/health`
  * `GET /api/desktop/catalog`

To assemble the local support tree used by the desktop shell:

  * Run `scripts/desktop/build_support_tree.sh`
  * The default output is `.desktop/bundle`
  * To run the bundled local runtime directly, use `scripts/desktop/run_local_runtime.sh`

The shared desktop variant catalog is written to:

  * `shared/ui/generated/desktop-variant-catalog.json`

Ready to deploy? Please [check Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Source: https://github.com/phoenixframework/phoenix

# Attribution

 * Dice Images: https://game-icons.net/tags/dice.html
 * Dice Favicon: https://www.favicon.cc/?action=icon&file_id=927484
