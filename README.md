# Homebrew for Unicity AOS

Official Homebrew formulae for Unicity AOS Community Edition. Before the first
signed stable-channel promotion, the tap intentionally contains no installable
formula.

```sh
brew install unicity-aos/tap/aos
```

The formula installs the `aos` product command together with the exact Astrid
Runtime release pinned by that AOS release. `aos self-update` delegates back to
Homebrew so the product command and runtime remain one coordinated package.

The tap follows only the signed `stable` channel published by
`unicity-aos/aos-ce`. A scheduled workflow authenticates the channel pointer,
its immutable release metadata, readiness gates, release source commit, and
per-platform SHA-256 values before atomically committing the formula and the
accepted channel evidence. There is no manual version override.

AOS versions use `YYYY.MINOR.PATCH`: the year is the calendar component, while
minor and patch retain ordinary SemVer meaning and are not months.
