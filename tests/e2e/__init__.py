# Package marker so this nested test dir imports as `e2e.*` rather than putting a
# second top-level `conftest` on sys.path — which would shadow tests/conftest.py
# and break the flat tests' `from conftest import REPO_ROOT`.
