import os
import sys

# Ensure the Python package under ``python/`` is importable when tests are run
# from the repository root by adding the package directory to ``sys.path``.
sys.path.insert(
    0, os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
)


def test_import():
    import mlc_llm

    assert mlc_llm is not None
