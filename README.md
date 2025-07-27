[![CI - Tests, Linting](https://github.com/vet-run/vet/actions/workflows/ci.yml/badge.svg)](https://github.com/vet-run/vet/actions/workflows/ci.yml)

`vet` is a command-line tool that acts as a safety net for the common but risky `curl | bash` pattern. It lets you inspect remote scripts for changes, run them through a linter, and require your explicit approval before they can execute.

**Don't just run it, `vet` it.**

---

## The Problem

We've all seen this pattern for installing software:

```bash
# This is convenient, but you're blindly trusting the remote script.
curl -sSL https://example.com/install.sh | bash
```

This is dangerous. The script could be malicious, the server could be compromised, or a transient network error could result in executing a partial script.

### The Solution: vet

`vet` wraps this process in a secure, interactive workflow:

-   **Fetch:** It downloads the remote script to a temporary location.

-   **Diff & Review:** It shows you what, if anything, has changed since the last time you ran this script.

-   **Lint:** If you have shellcheck installed, it automatically analyzes the script for potential bugs or malicious patterns.

-   **Confirm:** It prompts you for explicit approval before executing anything.

```bash
# The new, safer way.
vet https://example.com/install.sh
```

## Installation

We believe you should never blindly trust a script from the internet—not even ours. That's why `vet` exists. The installation process itself is a perfect demonstration of the problem `vet` solves.

## Homebrew

For macOS users, the easiest and recommended way to install `vet` is via Homebrew.
```
# First, tap the official repository
brew tap vet-run/vet

# Now, install the formula
brew install vet-run
```
**Note:** The formula is named `vet-run` to avoid a conflict with another tool in the Homebrew ecosystem, but this command will correctly install the `vet` executable on your system.

## Community Packages

### Arch Linux

Installation from the Arch User Repository (AUR) is recommended for users of Arch or Arch-based Linux distributions. The official procedure is documented [here](https://wiki.archlinux.org/title/Arch_User_Repository#Installing_and_upgrading_packages), but here are the steps:
```
# First, clone the AUR git repo
git clone https://aur.archlinux.org/vet.git

cd vet

# Now, as you should always do, review the PKGBUILD!
cat PKGBUILD

# Next, build the package and install
makepkg -si
```
Use the [vet](https://aur.archlinux.org/packages/vet) package for stable releases, and the [vet-git](https://aur.archlinux.org/packages/vet-git) package for the latest vet commit.

**Note:** These installation steps (and package updates) can of course be automated via an AUR helper such as [yay](https://github.com/Jguer/yay) or [paru](https://github.com/morganamilo/paru). But, as with the security principle that `vet` promotes, you should still read the PKGBUILD before building and installing the package.

## Manual Installation

### The Safe Way
If you don't use macOS/Arch Linux, or if you simply wish to follow the security-first principle that `vet` champions, you can perform a manual installation. This is the two-step "Download, then Review" process that demonstrates exactly what `vet` automates for you.

1. **Download the installer**:

Choose one of the following sources. The first is the official project domain, and the second is a direct link to the GitHub release asset.

*Option A: Official project domain*
```bash
curl -o install_vet.sh https://getvet.sh/install.sh
```
*Option B: Direct GitHub Release Link*
```bash
curl -L -o install_vet.sh https://github.com/vet-run/vet/releases/latest/download/install.sh
```
2. **Review the installer's code.** Open it in a text editor or use `less -U` to ensure it's not doing anything suspicious. It's a simple script that downloads the correct vet script and moves it to /usr/local/bin.
```bash
less -U install_vet.sh
```
3. **Run the installer you just vetted:**
```bash
bash install_vet.sh
```

Congratulations! You just manually performed the process that vet will now automate for you.

### The "Trusting" One-Liner (The Anti-Pattern)
```bash
# This is the curl-to-bash pattern.
# Don't actually do this. That's the whole point.
curl -sL https://getvet.sh/install.sh | bash
```
---
### Usage
```bash
# Basic usage
vet <URL>

# Example with a real-world installer
vet https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh

# Pass arguments to the remote script
# All arguments after the URL are passed directly to the script.
vet https://example.com/setup.sh --user myuser --version latest

# Non-interactive mode for trusted scripts in automated environments (e.g., CI/CD)
vet --force https://my-trusted-internal-script.sh
```

#### Options

\-f, \--force

Skip all interactive prompts and execute immediately. Use with caution.

\-h, \--help

Display the help message.

## Project Philosophy & Technical Decisions

### Bash 4+ is a Required Dependency

`vet` is intentionally written to leverage modern bash features (arrays, \[\[ ... \]\], pipefail). We believe that for a security-focused tool, sacrificing robustness and readability for POSIX sh compatibility would be a dangerous trade-off.

The safety features provided by modern bash are non-negotiable for `vet`'s mission.

If you are in a minimal environment (like an Alpine container), please install bash as an explicit dependency:
```bash
apk add --no-cache bash
```
## Contributing

Contributions are welcome! If you have an idea for a new feature or have found a bug, please open an issue. For pull requests, please ensure that your changes are covered by tests.

-   Fork the repository.

-   Create a new feature branch (git checkout -b feature/my-amazing-feature).

-   Make your changes.

-   Run the tests (bats tests/).

-   Commit your changes (git commit -am 'Add some amazing feature').

-   Push to the branch (git push origin feature/my-amazing-feature).

-   Open a new Pull Request.

## Acknowledgements

This project is made better by its contributors. See our [Contributors](CONTRIBUTORS.md) file to recognize those who have helped shape `vet`.

## License

This project is licensed under the MIT License - see the [LICENSE](https://spdx.org/licenses/MIT.html) file for details.
