# Trictrac Rules Sources

These three directories are tracked as `git subtree` imports from the active upstream repositories that provide the in-game rules library:

- `traiteCompletTrictrac` from `https://github.com/mmai/traiteCompletTrictrac.git`
- `coursCompletdeTrictrac` from `https://github.com/mmai/coursCompletdeTrictrac.git`
- `leJeuDeTrictracRenduFacile` from `https://github.com/mmai/leJeuDeTrictracRenduFacile.git`

Each upstream is imported from its `main` branch with `--squash`.

## Initial add commands

```sh
git subtree add --prefix=gamedocs/sources/traiteCompletTrictrac https://github.com/mmai/traiteCompletTrictrac.git main --squash
git subtree add --prefix=gamedocs/sources/coursCompletdeTrictrac https://github.com/mmai/coursCompletdeTrictrac.git main --squash
git subtree add --prefix=gamedocs/sources/leJeuDeTrictracRenduFacile https://github.com/mmai/leJeuDeTrictracRenduFacile.git main --squash
```

## Update commands

```sh
git subtree pull --prefix=gamedocs/sources/traiteCompletTrictrac https://github.com/mmai/traiteCompletTrictrac.git main --squash
git subtree pull --prefix=gamedocs/sources/coursCompletdeTrictrac https://github.com/mmai/coursCompletdeTrictrac.git main --squash
git subtree pull --prefix=gamedocs/sources/leJeuDeTrictracRenduFacile https://github.com/mmai/leJeuDeTrictracRenduFacile.git main --squash
```
