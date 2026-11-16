[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/vaxul/ddev-safe-chain/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/vaxul/ddev-safe-chain/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/vaxul/ddev-safe-chain)](https://github.com/vaxul/ddev-safe-chain/commits)
[![release](https://img.shields.io/github/v/release/vaxul/ddev-safe-chain)](https://github.com/vaxul/ddev-safe-chain/releases/latest)

# DDEV Safe Chain

## Overview

[Aikido Safe Chain](https://github.com/AikidoSec/safe-chain) checks packages against a malware database before a package manager installs them. By default it also blocks package versions released less than 48 hours ago.

This add-on installs Safe Chain in the `web` container of your [DDEV](https://ddev.com/) project. It wraps `npm`, `npx`, `yarn`, `pnpm`, `pnpx`, `bun`, `bunx`, `rush`, `rushx`, `pip`, `pip3`, `pipx`, `python`, `python3`, `uv`, `uvx`, `poetry`, and `pdm`, so every install in the container is checked:

- `ddev npm`, `ddev yarn`, and other DDEV commands
- `ddev exec` and `ddev ssh`
- scripts and tools that call a package manager, such as Composer scripts
- your own `.ddev/web-build/Dockerfile*` files that sort after `Dockerfile.safe-chain`

## Installation

```bash
ddev add-on get vaxul/ddev-safe-chain
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control, so everyone on the team gets the same protection.

## Usage

There is nothing to run. Use your package managers as before. To check that Safe Chain is active:

| Command | Expected result |
| ------- | --------------- |
| `ddev npm safe-chain-verify` | `OK: Safe-chain works!` |
| `ddev exec command -v npm` | `/usr/local/safe-chain/shims/npm` |

A package with known malware stops the command with an error, for example Aikido's test package:

```bash
ddev exec 'mkdir -p /tmp/t && cd /tmp/t && echo {} >package.json && npm install safe-chain-test'
```

## Configuration

Safe Chain reads its settings from environment variables. Set them for the `web` container with a labeled env file, for example to lower the minimum package age to 24 hours:

```bash
ddev dotenv set .ddev/.env.web.safe-chain --safe-chain-minimum-package-age-hours=24
ddev restart
```

See the [Safe Chain documentation](https://github.com/AikidoSec/safe-chain) for all settings, such as `SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS` and custom registries.

## Updating Safe Chain

The add-on installs the latest Safe Chain release when DDEV builds the `web` image. Docker keeps that build step in its cache, so to update Safe Chain, rebuild the image without cache:

```bash
ddev restart --no-cache
```

A DDEV upgrade also rebuilds the image. The malware database itself is downloaded when a package manager runs, not at build time.

## Using Safe Chain in Every Project

DDEV v1.25.4 and later apply Dockerfiles in `~/.ddev/web-build/` to every project. To protect all projects on your machine, put the add-on's Dockerfile there instead of installing the add-on in each project:

```bash
mkdir -p ~/.ddev/web-build
curl -fsSL https://raw.githubusercontent.com/vaxul/ddev-safe-chain/main/web-build/Dockerfile.safe-chain -o ~/.ddev/web-build/Dockerfile.safe-chain
```

Then restart your projects. To undo it, delete `~/.ddev/web-build/Dockerfile.safe-chain` and restart them again.

## Notes

- Building the `web` image needs access to GitHub. If the Safe Chain install fails, the build fails instead of starting the project without protection.
- Package installs need access to Aikido's malware database. Safe Chain caches it inside the container, so the first install after `ddev restart` downloads it again, which takes a few seconds.
- Wrapping `python` and `python3` catches `python -m pip`, and adds a short delay to every Python call.
- Safe Chain is a product of [Aikido Security](https://www.aikido.dev/) and has its own [license](https://github.com/AikidoSec/safe-chain/blob/main/LICENSE). This add-on doesn't include Safe Chain, it downloads it during the image build.

## Removal

```bash
ddev add-on remove safe-chain
ddev restart
```

## Credits

**Contributed and maintained by [@vaxul](https://github.com/vaxul)**
