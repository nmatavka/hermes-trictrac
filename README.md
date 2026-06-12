![](./assets/static/images/trictrac-wordmark.svg)

# Introduction

This is a monorepository that contains essentially everything you need to start your own multiplayer online tables server, with social (powered by Bluesky), ML/AI, and tournament functionality. Most major tables games are supported. For ease of use, they have been divided into two sections. **List A** contains backgammon, trictrac, trictrac à écrire, trictrac combiné, toc, and toccategli. The majority of energy has gone into List A primarily because of the rule-complexity of the games on it (not including backgammon).

**List B** contains tapa, jacquet, bräde, garanguet, tavli (a repeating loop of backgammon, tapa, and jacquet), sbaraglio, sbaraglino, plein, tourne-case, and dames rabattues. *Not all of these have been fully implemented.* In terms of rule-complexity, it is likely that bräde is heaviest; not coincidentally, bräde is next to be fully audited and, if by chance it hasn't fully been implemented, it will be.

If you're not quite sure what a tables game is, this class includes all, and only, those stochastic games that can be played on a backgammon board. Be warned that this does **not necessarily** mean they are even remotely similar as a class; the name refers to the *equipment* only (fifteen black and fifteen white pieces, all identical, one board with twelve points, and two or three dice).

Most of this is a Web service. If you are **not** a Web developer, we instead invite you to play at [trictrac.hermes.cx](trictrac.hermes.cx); honestly, this applies even if you **are** a Web developer.

## Technologies Used

The multi-game itself is a Phoenix 1.8 app with a React frontend over Phoenix Channels. The code that powers it is, therefore, in Elixir. The social portion of the game is likewise in Elixir. If functional or event-driven programming is new to you, enjoy this gentle introduction.

The AI trainer is in Julia with a BEAM bridge. Take note that it is *highly* demanding, and on the **CPU** side; for tactical shaping (a must!), you will want *at least* 96GB of memory and a processor that doesn't suck. A consumer GPU is good to have, but not necessary. Keep in mind that compute requirements for tactical shaping scale *exponentially*.

There is also a phone app in Kotlin and a desktop app in Haskell. These are in extremely early condition and untested.



## Game Structure

### Event-Driven Games

Other than backgammon, the List A games are **event-driven**. This means that every turn is effectively a loop of `roll -> score -> move -> pass dice`, with the `score` portion containing any number of flags which can be set either to `true` or `false`, or to `0`, `1`, `2`, or `3`. Each flag has a scoring tariff. Winning is by point accumulation.

Above and below this basic loop is the scoring architecture (that part of the game that defines *how* the points are accumulated). This can be to a linear equation (*2m + n = 12* or *4w + 3x + 2y + z = 12*), to a variable (to *M* marks, with any given mark *p1, p2,... pM* consisting of *q > 6*, each *q* consisting of 12 points, thus *r* total, greater *r* at time *M* wins), or to an integer constant.

Moving is *not a necessary condition* to score, and scoring follows Boolean logic (cf. "if *B* and not *C*, then you win *a* points on the opponent's behalf").

The *telos* of event-driven games is **not** to race. Reaching the end of the board is merely an auditing event with a consequent token reward, followed by the immediate and unceremonious resumption of play.

We are aware the above description may sound like the idle vapourings of a mind diseased—or like a finite state machine. Take your pick; we disclaim all responsibility in any event. Those who wish to inquire further may take it up with Me Euverte de Jollivet, sieur de Votilley.

### Multiplex Race Games

Backgammon and most of the List B games have a different structure. They are *race* games in that the object is to get all of one's pieces to a defined objective (in this case, off the board). They are *multiplex* in that, every turn, out of *u* pieces, one selects up to *v* to move. The point-scoring element is greatly reduced or absent, with the racing element privileged in exchange; the terminal win condition may, in most cases, be modelled as binary and categorical ("Marie won; Pierre lost"). That is a **complete** description of this family *qua* family.

What varies, as far as the developer is concerned, are the details. Do the pieces move parallel or contrariwise? Does moving one of your pieces onto one of the opponent's put him in a sort of 'gaol' (called the *bar*)? If not, does moving one of your pieces onto one of the opponent's pin him in place so he can't move? If not, is there a special piece which must be the *first* off the board? Two dice or three? Are doubles played once or twice, and how about *trebles*?

## Artificial Intelligence

This repository includes an artificial intelligence trainer written in Julia that is currently set up for **event-driven games** only. The reason for this is that, as designed, it is neither bird nor beast; it is **not** a clean example of a trainer of the AlphaZero type, **nor** is it a pure expectimax search or even deterministic.

In fact, it is a hybrid of both. The problem it was designed to solve is that, in event-driven games, it is conceivable (in actuality, it is true) that the primary scoring engines include the pre-positioning and the maintenance *in situ* of **complex structures**. The deliberately narrow definition we'll use is a structure that takes multiple turns to set up, and distributes rewards in a form akin to `[0, 0, 0.0417]`. (The prototypical complex structure is a capture in the game of go.)

Given infinite time, an AlphaZero-class trainer with a non-binary reward structure (with the reward term being the anticipated score differential between player and opponent, put through the traditional tanh wringer) would almost surely derive a reward function for such a game, irrespective of how weak and how delayed the tactical signal. Even odds on whether this would occur before or after an infinite number of simians would reproduce the complete literary works of one Wm Shakespeare, Esq.

Needless to say, we do not have infinite time for stochasticity to do the work for us. The solution chosen was to have a sort of finite-horizon tactical oracle that could highlight locally-promising lines of play. This is hard CPU work.

What's even harder CPU work is that this is a fine example of the **managed code problem**. Elixir code, much like Java, runs on a virtual machine. Virtualisation inherently incurs a speed penalty. What we have now could certainly be improved—for instance, by reproducing the entire rules of all five event-driven games in Julia. Whether that would be a good use of labour is left as an exercise for the reader.

We will note that we have had good results with an AMD EPYC 7C13 processor and 256 gigabytes of memory. A graphics card is recommended, though optional.

For games in the race family, this architecture is in large part unnecessary, and in fact likely unwanted: no reasonable backgammon engine *needs* to learn about fractional win margins, and complex structures as defined above don't form part of the rules. Notwithstanding some technicalities (i.e. equity can vary, as with all gambling games), wins and losses in backgammon are binary, and treating them as fractional would simply be wrong (in the sense that 'Alice's expected score was 0.125 more than Bob's', which is actually a perfectly cromulent reward function for trictrac!). Thus, for race-class training, we can only recommend standard AlphaZero, preferably in Julia for interoperability.



# Instructions for Deployment

## Phoenix / Web Service

This application is a Phoenix `1.8` service with cookie-backed sessions. It is not a typical “wire up Postgres and go” Phoenix deployment: the current root app does **not** require a database for normal operation.

What it does require in production:

  * Elixir `~> 1.18`
  * Node/npm to build assets
  * a writable filesystem for release assets, logs, and Bluesky OAuth session storage
  * Julia only if you want the bundled model bot
  * Docker only if you want the default Docker-backed Julia/bridge bot path

### Local Development

To start the development server:

  * Install dependencies with `mix deps.get`
  * Install frontend dependencies with `cd assets && npm install`
  * Start Phoenix with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Identity defaults to manual in local development, so you do not need Bluesky OAuth keys just to bring up the lobby and tables UI.

### Build And Release

To build production assets:

  * Run `mix assets.deploy`

To build a release:

  * Run `MIX_ENV=prod mix deps.get`
  * Run `MIX_ENV=prod mix assets.deploy`
  * Run `MIX_ENV=prod mix release`

Minimal production start:

```sh
PHX_SERVER=true \
SECRET_KEY_BASE="$(mix phx.gen.secret)" \
_build/prod/rel/hermes_trictrac/bin/hermes_trictrac start
```

### Runtime Configuration

The core runtime knobs come from [`config/runtime.exs`](./config/runtime.exs).

Important Phoenix/web variables:

  * `PHX_SERVER`
    Enable the HTTP server in a release.
  * `SECRET_KEY_BASE`
    Required in normal production mode.
  * `PHX_HOST`
    Public hostname for generated URLs and OAuth callback construction.
  * `PORT`
    HTTP listen port. Defaults to `4000`, or `4050` in local desktop mode.
  * `PHX_URL_SCHEME`
    Public URL scheme. Defaults to `https` in production, `http` otherwise.
  * `PHX_URL_PORT`
    Public URL port override. If unset, defaults to `443` for `https` and `80` for `http` in production.

Important Hermes identity variables:

  * `HERMES_TRICTRAC_IDENTITY_MODE`
    `manual` or `bluesky_oauth`.
  * `HERMES_TRICTRAC_CLIENT_ID_SCOPE`
    `tab` or `browser`. Defaults to `tab`.

Identity mode defaults are:

  * development: `manual`
  * production: `bluesky_oauth`
  * local desktop mode: `manual`

That means a plain production release will try to enforce Bluesky sign-in for table access unless you explicitly override it.

### Bluesky OAuth Deployment

Bluesky OAuth is wired through the bundled `hermes_bluesky` / `atex` stack and the app’s `/auth/bluesky/...` routes.

If `HERMES_TRICTRAC_IDENTITY_MODE=bluesky_oauth` or you accept the default production identity mode, you must set:

  * `HERMES_TRICTRAC_ATPROTO_OAUTH_PRIVATE_KEY`
  * `HERMES_TRICTRAC_ATPROTO_OAUTH_KEY_ID`

Optional but important:

  * `HERMES_TRICTRAC_ATPROTO_SERVICE_DID`
    The service DID used as the ATProto audience value.
  * `ATEX_PLC_DIRECTORY_URL`
    Overrides the PLC directory base URL. Default is `https://plc.directory`.

The OAuth callback base URL is derived from:

  * `PHX_HOST`
  * `PHX_URL_SCHEME`
  * `PHX_URL_PORT`

so those must describe the **public** address users actually hit.

If you need an emergency fallback without Bluesky identity, force:

```sh
HERMES_TRICTRAC_IDENTITY_MODE=manual
```

#### OAuth Session Storage

OAuth sessions are stored by default in a DETS file, not in your browser cookie. The default path is:

```text
priv/dets/atex_oauth_sessions.dets
```

relative to the running release. That file must live on writable storage if you want OAuth sessions to persist across restarts.

For a single-node deployment, the default DETS store is fine. For a multi-node deployment, you will likely want to replace it with a shared session store.

### Optional Julia Model Bot

The web app can launch a Julia-powered TricTrac bot through [`HermesTrictrac.TrictracModelBot`](./lib/hermes_trictrac/trictrac_model_bot.ex). This is optional for deployment of the web service itself, but required if you
want AI table opponents.

Useful runtime variables for the model bot:

  * `HERMES_TRICTRAC_BOT_PROJECT_DIR`
    Path to the `trictrac_zero` project.
  * `HERMES_TRICTRAC_BOT_SCRIPT`
    Julia entrypoint script. Defaults to `scripts/frontend_bot.jl`.
  * `HERMES_TRICTRAC_BOT_SESSION_DIR`
    Default model session directory.
  * `HERMES_TRICTRAC_BOT_JULIA`
    Julia executable path.
  * `HERMES_TRICTRAC_BOT_NAME`
    Display name for the bot.

If you use the default Docker-backed bridge/tooling around the Julia bot, the repo layout assumption is still `/root/backgammon`. If your deployment uses a different path, adjust the bridge launcher or override the bot/bridge paths explicitly.

## Trainer

### Example

```shell
$ julia --project scripts/train.jl --cpu-policy max --iterations 200 --game classique --target-gain 4 --move-cap 2000 --tactical-horizon-own-turns 1
```

### Deployment Notes

The trainer is not a lightweight sidecar. For `classique` with tactical shaping enabled, treat it as a **CPU-first deployment** with heavy memory pressure on the bridge side.

Recommended practical floor for a dedicated remote trainer box:

  * `>= 96GB` RAM
  * a fast many-core CPU
  * Docker installed and usable by the launch user
  * `tmux` or equivalent process supervision
  * swap configured; `64GB` has been a good operational baseline on large CPU boxes

If you are using the default bridge launcher in
[`trictrac_zero/scripts/bridge_container_runner.sh`](./trictrac_zero/scripts/bridge_container_runner.sh),
note that it currently mounts the repository at `/root/backgammon`. The easiest path is therefore:

  * clone or sync this repo to `/root/backgammon`
  * run the trainer from `/root/backgammon/trictrac_zero`

If your checkout lives somewhere else, either adjust that script or export a different `TRICTRAC_ZERO_BRIDGE_EXECUTABLE`.

#### Fresh Box Checklist

On a new remote CPU trainer machine, the minimum useful setup is:

  * install Julia `1.12.x`
  * install Docker
  * install `tmux`
  * sync the repo, including the Julia project and the compiled Elixir `_build/dev/lib` tree if you want the bridge to work immediately

If you need to create swap quickly on Linux:

```sh
fallocate -l 64G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=65536 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
printf 'vm.swappiness=10\n' > /etc/sysctl.d/99-trictrac-swappiness.conf
sysctl -p /etc/sysctl.d/99-trictrac-swappiness.conf
```

#### Remote Launch Pattern

For CPU training with the Docker-backed bridge, the most reliable launch shape has been:

```sh
cd /root/backgammon/trictrac_zero
export TRICTRAC_ZERO_BRIDGE_EXECUTABLE=/root/backgammon/trictrac_zero/scripts/bridge_container_runner.sh
export TRICTRAC_ZERO_BRIDGE_EBIN_ROOT=/root/backgammon/_build/dev/lib
export TRICTRAC_ZERO_BRIDGE_MODE=worker

tmux new-session -d -s trictrac_train \
  "cd /root/backgammon/trictrac_zero && \
   export TRICTRAC_ZERO_BRIDGE_EXECUTABLE=/root/backgammon/trictrac_zero/scripts/bridge_container_runner.sh && \
   export TRICTRAC_ZERO_BRIDGE_EBIN_ROOT=/root/backgammon/_build/dev/lib && \
   export TRICTRAC_ZERO_BRIDGE_MODE=worker && \
   script -q -e -f /root/trictrac_train.log -c '/opt/julia-1.12.5/bin/julia --project scripts/train.jl --cpu-policy max --iterations 200 --game classique --target-gain 4 --move-cap 2000 --tactical-horizon-own-turns 1'"
```

Notes:

  * `TRICTRAC_ZERO_BRIDGE_MODE=worker` is the preferred mode for CPU boxes. It gives each logical worker its own bridge daemon instead of routing all CPU-side tactical work through one shared daemon.
  * `script -e` is important. Without it, an OOM-killed Julia process can leave a misleadingly clean-looking `Script done ... [COMMAND_EXIT_CODE="0"]` footer in the log.
  * `--cpu-policy max` will re-exec Julia to use the full visible core count unless you override threads explicitly.

#### Monitoring

Useful remote checks while a run is live:

```sh
tail -f /root/trictrac_train.log
```

```sh
free -h
swapon --show
ps -eo pid,pcpu,pmem,rss,etime,comm,args --sort=-pcpu | head -n 20
```

```sh
journalctl -k --since '10 minutes ago' --no-pager | tail -n 80
```

The most common operational failure mode has been memory pressure from long-lived bridge daemons rather than raw Julia compute. If a run appears to stop unexpectedly, check the kernel log for OOM-killer entries before assuming the trainer exited cleanly.

### Options

```
--device <cpu|cuda|metal|auto>
    Select the execution backend. Default: cpu.
--gpu
    Compatibility alias for --device=auto.
--reset-memory
    Reset only the replay buffer before resuming an existing session.
--cpu-policy <headroom|max|conservative|off>
    Set the automatic CPU policy. Default: headroom.
--cpu-threads <auto|N>
    Set Julia master threads directly. Explicit values override policy.
--self-play-workers <auto|N>
    Set self-play worker count. 'auto' restores derived behaviour.
--arena-workers <auto|N>
    Set arena worker count. 'auto' restores derived behaviour.
--iterations <N>
    Set the total session iteration target explicitly.
--move-cap <N>
    Set the temporary hard cap on game length. Use 0 to disable.
--target-gain <N>
    Set the tanh gain used for value-target shaping. Lower is less slope-y.
--tactical-shaping <on|off>
    Toggle tactical tariff shaping for Trictrac classique.
--tactical-horizon-own-turns <0|1|2|3>
    Set the tactical shaping horizon in own turns.
--tactical-reward-weight <N>
    Set the delta-reward tactical shaping weight.
--tactical-heuristic-weight <N>
    Set the heuristic tactical shaping weight.
--partie-length-repeats <auto|N>
    For a ecrire/combine training, use N self-play games at each marque target.
--game <classique|classique-margot|aecrire|aecrire-margot|combine|combine-margot|toc|toc-margot|toccategli|toccategli-margot>
    Choose the training target. Default: classique.
--help
    Show this help and exit.
```

### Environment

- `TRICTRAC_ZERO_CPU_POLICY`
- `TRICTRAC_ZERO_CPU_THREADS`
- `TRICTRAC_ZERO_SELF_PLAY_WORKERS`
- `TRICTRAC_ZERO_ARENA_WORKERS`
- `TRICTRAC_ZERO_NUM_ITERS`
- `TRICTRAC_ZERO_TEMP_MAX_GAME_LENGTH`
- `TRICTRAC_ZERO_VALUE_TARGET_GAIN`
- `TRICTRAC_ZERO_TACTICAL_SHAPING`
- `TRICTRAC_ZERO_TACTICAL_HORIZON_OWN_TURNS`
- `TRICTRAC_ZERO_TACTICAL_REWARD_WEIGHT`
- `TRICTRAC_ZERO_TACTICAL_HEURISTIC_WEIGHT`
- `TRICTRAC_ZERO_PARTIE_LENGTH_REPEATS`
- `TRICTRAC_ZERO_GAME`

### Precedence

  CLI values override environment variables; environment variables override defaults.

## Desktop Foundation

The repo now includes a native desktop foundation under
`haskell/hermes-desktop`.

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

The shared desktop variant catalogue is written to:

  * `shared/ui/generated/desktop-variant-catalog.json`

# Learn more

## How to Play

There are eight games in this collection. Among these, the most rule-dense are the Group A games and bräde. All of our supported games have been collected in the form of a parallel translation in our multilingual compilation, which can be found at `/gamedocs/multilingual/Das Trictrac- und Toccategli-Spiel.md`. The compilation does not include English; from the anglophone perspective, it is invaluable to consult [Wikipedia](https://en.wikipedia.org/wiki/Trictrac).

### Trictrac

There are two absolutely invaluable, semi-official rulebooks for the basic game of trictrac. Both were bound together in an anthology entitled *L'Académie universelle des jeux*, which is available [here](https://archive.org/details/academie-universelle-des-jeux-good-copy). [Danish](https://archive.org/details/nyeste-dansk-spillebog), [Swedish](https://archive.org/details/konsten-att-spela-kort-boll-tarnings-good-copy), and multiple German editions of the same rules exist (in different contexts, i.e. with different games included in the respective collections).

The balance of probabilities, however, is that the original work was published in French and that the others are effectively verbatim translations.

There are also two further Git repositories (also in French) [here](https://github.com/mmai/leJeuDeTrictracRenduFacile) and [here](https://github.com/mmai/traiteCompletTrictrac); these reproduce the work of Nicolas Guiton and Julien Lelasseux-Lafosse.

### Trictrac à écrire

The chief source for the rules for trictrac à écrire is [here](https://archive.org/details/joueur-parfait). The relevant rules were reprinted verbatim numerous times, the first time by Ján Tamás de Trattner in Vienna, other times in various anthologies of games. The source given here is called *Le Joueur parfait*; it is effectively the same as *L'Académie des jeux* with a few additional games and materially worse typography.

This game is only historically described in French, but its mature, currently played form almost certainly originated in Austria.

### Trictrac combiné

There is as yet only one documented historical source for trictrac combiné. It can be found [here](https://gallica.bnf.fr/ark:/12148/bpt6k1915370v/f1.item.texteImage). This is an intellectually demanding game, with play time equivalent to trictrac à écrire but with far higher mental load.

### Bräde

Bräde is described, at least by its official governing body (the Swedish Tables Association, which meets regularly at the *Vasa* Museum), in two languages: [Swedish](https://www.vasamuseet.se/globalassets/vasamuseet/dokument/vasamuseets-vanner/t_nya-svenska-bradspelsregler.pdf) and [English](https://www.vasamuseet.se/globalassets/vasamuseet/dokument/vasamuseets-vanner/t_bradspelsregler-engelska.pdf). 

Historical rules for bräde, under the name **révertier** or **førkæring**, are found in *L'Académie universelle des jeux* and *Le Joueur parfait*, as well as the translations noted above.

### Tapa

Tapa is described [here](https://skikrakra.wordpress.com/дейност-3/спортна-табла/видове-табла/) and [here](https://tabla.bg/blog/vidove-tabla/) (in Bulgarian). Its Arabic name is mahbousa and its Greek name is plakoto.

### Jacquet (Pheuga) and Garanguet

Jacquet is ubiquitous in France; it is also popular in Greece. Garanguet is more obscure. For those new to either game, though, published rules are available in [this](https://github.com/mmai/coursCompletdeTrictrac) Git repository, which contains a trictrac manual written by P. M. M. Lepeintre, to which they were added as appendices. **We do not recommend this manual for learning trictrac**; Lepeintre has an unfortunate habit of pointlessly bloviating about the moral panics of his day and age, about (occasionally imprecise) history, about politics, about literature...

## Phoenix/Elixir

  * Official website for Phoenix: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Source: https://github.com/phoenixframework/phoenix
