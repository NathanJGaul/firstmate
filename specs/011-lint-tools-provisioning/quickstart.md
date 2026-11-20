# Quickstart: Pinned Lint Tools Visible to the No-Mistakes Pipeline

Provision the managed directory once per machine:

```sh
bin/fm-install-lint-tools.sh
bin/fm-install-lint-tools.sh --check
```

Prove resolution from a daemon-like clean environment:

```sh
env -i HOME="$HOME" PATH=/usr/bin:/bin bin/fm-lint.sh --required-version
bin/fm-test-run.sh tests/fm-lint-tools.test.sh
```

Expected: `--check` exits 0 naming both pins, and a second provisioning run downloads nothing.
