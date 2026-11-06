#!/usr/bin/env bash
# Runs once after the container is created. Works on Docker Desktop, Docker
# Engine and OrbStack (amd64 and arm64): everything here is architecture-neutral.
set -euo pipefail

# Named volumes are created root-owned; hand them to the dev user.
sudo chown -R "$(id -u):$(id -g)" "$HOME/.claude" "$HOME/.config"
sudo mkdir -p "$PLAYWRIGHT_BROWSERS_PATH" && sudo chown "$(id -u):$(id -g)" "$PLAYWRIGHT_BROWSERS_PATH"

# uv manages the Python interpreters (3.13 and 3.14) and their virtualenvs.
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
grep -q '.local/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

# Basic numeric/optimization libraries. Headless OpenCV: no GUI deps needed.
PKGS=(numpy scipy numba opencv-python-headless pytest playwright)

for v in 3.13 3.14; do
  uv python install "$v"
  uv venv --python "$v" --clear "$HOME/.venvs/py$v"
  # Don't fail the whole container if a wheel isn't available yet for a version.
  uv pip install --python "$HOME/.venvs/py$v/bin/python" "${PKGS[@]}" \
    || echo "WARNING: some packages failed to install for Python $v"
done

# Playwright + Chromium (Node and Python bindings share one browser cache).
# --with-deps apt-installs the system libraries Chromium needs (amd64 and arm64).
sudo env "PATH=$PATH" npm install -g playwright
sudo env "PATH=$PATH" PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" \
  playwright install --with-deps chromium
sudo chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"
# Python bindings: same browser cache; Python playwright may pin a different
# Chromium build, so fetch it too (no-op if already present).
"$HOME/.venvs/py3.13/bin/python" -m playwright install chromium

# Default interpreter is 3.13; use `py314` for 3.14.
cat >> "$HOME/.bashrc" <<'RC'
export VIRTUAL_ENV="$HOME/.venvs/py3.13"
export PATH="$VIRTUAL_ENV/bin:$PATH"
alias py313="$HOME/.venvs/py3.13/bin/python"
alias py314="$HOME/.venvs/py3.14/bin/python"
RC
