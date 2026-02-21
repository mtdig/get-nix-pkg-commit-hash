# get-nix-pkg-commit-hash

Find the nixpkgs commit that introduced a specific version of a Nix package.

This is useful when you need to pin a package to an exact version using `fetchTarball` with a specific nixpkgs commit hash.

## Requirements

- [Nix](https://nixos.org/) (with `nix search` and `nix eval` support)
- `jq`
- `curl`
- `bash`

## Usage

```bash
./get-nix-pkg-commit-hash.sh <package-name> <version>
```

### Example

```bash
./get-nix-pkg-commit-hash.sh virtualbox 7.2.6
```

## How it works

1. **Package lookup** — Searches nixpkgs for the given package name and verifies it exists as a top-level attribute. If no exact match is found, it shows up to 10 possible matches.

2. **Source path resolution** — Uses `nix eval` to read `meta.position` and determine which file in the nixpkgs tree defines the package. Falls back to common path patterns if `meta.position` is unavailable.

3. **Commit search** — Queries the GitHub API for recent commits that touch the resolved file path, then filters commit messages for the requested version string.

4. **Output** — Prints the matching commit SHA(s) and message(s), or shows recent commits for manual inspection if no version match is found.

## Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Found a commit matching the requested version |
| `1`  | Package not found, version not found, or usage error |

## Limitations

- Only searches the last 50 commits per file path via the GitHub API.
- Relies on commit messages containing the version string.
- GitHub API rate limits apply (60 requests/hour unauthenticated).

## Running tests

```bash
./test.sh
```

See [test.sh](test.sh) for the test cases.
