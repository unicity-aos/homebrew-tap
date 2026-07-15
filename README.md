# Homebrew for Unicity AOS

Official Homebrew formulae for Unicity AOS Community Edition.

The stable formula is intentionally unavailable until the first approved,
signed AOS release is published. Once a stable release exists, this tap will
publish the formula automatically and the install command will be:

```sh
brew install unicity-aos/tap/aos
```

The formula installs the `aos` product command, the exact Astrid Runtime release,
and the Community Edition capsule set pinned by that AOS release. `aos self-update`
delegates back to Homebrew so the product command, runtime, and capsules remain one
coordinated package.
