# Upstream

Basalt tracks an upstream project, **Basilisk**, maintained by
Gornskew Enterprises (https://github.com/gornskew/basilisk), from
which it is periodically merged. This file is the one place in this
repository that records the relationship; the product documentation
does not depend on it.

**Shared with upstream, and kept compatible:** the generator, the
compose tooling, the MCP client registries, and the identifiers that
both projects' images and tooling rely on — the `basilisk.*` image
labels and compose labels, the `BASILISK_*` environment variables,
the `skewed-*` and `lisply-*` namespaces inside the console image.
These are compatibility contracts; renaming them is a versioned
behavior decision made with upstream, never a documentation edit.

**Deliberately different here:** the product name, the configuration
file name (`basalt.sexp`) and its vocabulary (`glossary.sexp`), the
service roles and display strings, the attribution, and the
documentation voice.

**Issues and fixes:** file issues against this repository. A fix that
applies to the shared code is carried upstream by the maintainers;
upstream changes are merged here when chosen.

Copyright © 2026 Gornskew Enterprises for the upstream work; Basalt
modifications copyright © 2026 Genworks International. Both under
the GNU Affero General Public License, version 3 or later.
