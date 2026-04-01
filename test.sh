#!/bin/bash
#===============================================================================
# Docker-based Test Script for setup.sh
#
# Tests that the setup script runs to completion in a clean Ubuntu 24.04
# container. Validates:
#   - All apt installs succeed
#   - All binary downloads/installs succeed
#   - All cargo/npm installs succeed
#   - Config file deployment works
#   - Script idempotency (can run twice without errors)
#
# Limitations (can't test in a container):
#   - Ghostty (requires display server)
#   - Pop Shell (requires GNOME)
#   - Setting default terminal
#   - Nerd Font rendering
#
# Usage:
#   ./test.sh              # Test remote mode
#   ./test.sh desktop      # Test desktop mode
#   ./test.sh both         # Test both modes
#   ./test.sh idempotent   # Test running desktop mode twice
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[TEST]${NC} $*"; }
success() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail()    { echo -e "${RED}[FAIL]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Check Docker is available
if ! command -v docker &>/dev/null; then
    fail "Docker is required to run tests"
    exit 1
fi

TEST_MODE="${1:-remote}"

# Generate a helper script that runs inside the container
# This avoids all nested quoting issues
make_runner_script() {
    local mode="$1"
    local runs="${2:-1}"
    local mode_flag=""
    if [ "$mode" != "remote" ]; then
        mode_flag="--mode $mode"
    fi

    cat <<RUNNER_EOF
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Install basics
apt-get update -qq
apt-get install -y -qq sudo git >/dev/null 2>&1

# Create test user with sudo
useradd -m -s /bin/bash testuser
echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
cp /etc/skel/.bashrc /home/testuser/.bashrc
chown testuser:testuser /home/testuser/.bashrc

# Copy setup files (read-only mount, so copy to writable location)
cp -r /setup /home/testuser/setup
chown -R testuser:testuser /home/testuser/setup

# Pre-set git config to avoid interactive prompts
su - testuser -c 'git config --global user.name "Test User"'
su - testuser -c 'git config --global user.email "test@example.com"'

# Run setup
for i in \$(seq 1 $runs); do
    echo ""
    echo "========== RUN \$i =========="
    su - testuser -c 'cd ~/setup && echo "" | ./setup.sh $mode_flag'
done
RUNNER_EOF
}

run_test() {
    local mode="$1"
    local label="$2"
    local runs="${3:-1}"

    log "=== $label ==="
    log "Mode: $mode | Runs: $runs | Image: ubuntu:24.04"
    log "This may take 10-20 minutes on first run (cargo builds)..."
    echo ""

    local runner
    runner=$(mktemp)
    make_runner_script "$mode" "$runs" > "$runner"
    chmod +x "$runner"

    if docker run --rm \
        -v "$SCRIPT_DIR:/setup:ro" \
        -v "$runner:/runner.sh:ro" \
        -e DEBIAN_FRONTEND=noninteractive \
        ubuntu:24.04 \
        bash /runner.sh; then
        success "$label — completed successfully"
        rm -f "$runner"
        return 0
    else
        fail "$label — failed"
        rm -f "$runner"
        return 1
    fi
}

echo ""
log "Setup Script Test Suite"
log "======================"
echo ""

FAILURES=0

case "$TEST_MODE" in
    remote)
        run_test "remote" "Remote Server Mode" || ((FAILURES++))
        ;;
    desktop)
        run_test "desktop" "Desktop Workstation Mode" || ((FAILURES++))
        ;;
    both)
        run_test "remote" "Remote Server Mode" || ((FAILURES++))
        echo ""
        run_test "desktop" "Desktop Workstation Mode" || ((FAILURES++))
        ;;
    idempotent)
        run_test "desktop" "Idempotency Test (desktop, run twice)" 2 || ((FAILURES++))
        ;;
    *)
        echo "Usage: $0 [remote|desktop|both|idempotent]"
        exit 1
        ;;
esac

echo ""
if [ "$FAILURES" -eq 0 ]; then
    success "All tests passed"
else
    fail "$FAILURES test(s) failed"
    exit 1
fi
