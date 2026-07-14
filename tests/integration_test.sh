#!/bin/sh
# Integration tests for decrypt_gnupg_sc and local-bottom script using Busybox

# Find shell to run with
RUN_SHELL="sh"
if command -v busybox >/dev/null; then
        RUN_SHELL="busybox sh"
fi
echo "Running integration tests with: $RUN_SHELL"

# Helper for test failures
fail() {
        echo "FAIL: $1" >&2
        exit 1
}

# Path constants
ROOT_DIR="/home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup"
DECRYPT_SCRIPT="$ROOT_DIR/system-root/lib/cryptsetup/scripts/decrypt_gnupg_sc"
BOTTOM_SCRIPT="$ROOT_DIR/usr/share/initramfs-tools/scripts/local-bottom/cryptgnupg_sc"

# Create sandbox
SANDBOX="$(mktemp -d)"
MOCK_BIN="$SANDBOX/bin"
mkdir -p "$MOCK_BIN"
mkdir -p "$SANDBOX/run"

cleanup() {
        # Kill any processes still running in the background of our sandbox
        pids=$(pgrep -f "$SANDBOX" 2>/dev/null)
        if [ -n "$pids" ]; then
                kill -9 $pids 2>/dev/null
        fi
        rm -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

# Build mocks
# Mock gpg
cat <<EOF > "$MOCK_BIN/gpg"
#!/bin/sh
case "\$*" in
        *--card-status*)
                if [ -f "$SANDBOX/gpg_card_status_fail" ]; then
                        exit 1
                fi
                echo "Reader:Yubikey"
                echo "fpr:1234567890ABCDEF"
                exit 0
                ;;
        *--decrypt*|*-d*)
                if [ -f "$SANDBOX/gpg_decrypt_fail" ]; then
                        exit 1
                fi
                echo "decrypted_key_data"
                exit 0
                ;;
esac
exit 0
EOF
chmod +x "$MOCK_BIN/gpg"

# Mock pcscd
cat <<EOF > "$MOCK_BIN/pcscd"
#!/bin/sh
if [ "\$1" = "--help" ]; then
        echo "  --disable-polkit"
        exit 0
fi
# Run in foreground so the parent gets the correct PID
exec sleep 100
EOF
chmod +x "$MOCK_BIN/pcscd"

# Mock gpg-agent
cat <<EOF > "$MOCK_BIN/gpg-agent"
#!/bin/sh
pid_file=""
while [ "\$#" -gt 0 ]; do
        case "\$1" in
                --pid-file)
                        pid_file="\$2"
                        shift 2
                        ;;
                *)
                        shift
                        ;;
        esac
done

if [ -n "\$pid_file" ]; then
        sleep 100 &
        echo \$! > "\$pid_file"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/gpg-agent"

# Mock plymouth
cat <<'EOF' > "$MOCK_BIN/plymouth"
#!/bin/sh
exit 0
EOF
chmod +x "$MOCK_BIN/plymouth"

# Mock askpass
cat <<'EOF' > "$MOCK_BIN/askpass"
#!/bin/sh
echo "mock_pin"
EOF
chmod +x "$MOCK_BIN/askpass"

# Export test environments
export PATH="$MOCK_BIN:$PATH"
export CRYPTSETUP_RUN_DIR="$SANDBOX/run"
export CRYPTSETUP_ASKPASS="$MOCK_BIN/askpass"
export GNUPGHOME="$SANDBOX/gnupg"
mkdir -p "$GNUPGHOME"

# -----------------
# Test 1: Successful decryption preserves daemons (deferred to local-bottom)
# -----------------
echo "Running Test 1: Successful decryption preserves daemons..."

# Run the decrypt script
$RUN_SHELL "$DECRYPT_SCRIPT" "$SANDBOX/key.gpg" || fail "decryption script failed"

# Check that PID files were written and processes are running
[ -f "$SANDBOX/run/pcscd.pid" ] || fail "pcscd.pid was not created"
[ -f "$SANDBOX/run/gpg-agent.pid" ] || fail "gpg-agent.pid was not created"

P_PID=$(cat "$SANDBOX/run/pcscd.pid")
A_PID=$(cat "$SANDBOX/run/gpg-agent.pid")

kill -0 "$P_PID" 2>/dev/null || fail "pcscd was not kept running"
kill -0 "$A_PID" 2>/dev/null || fail "gpg-agent was not kept running"

# -----------------
# Test 2: Local bottom script terminates the daemons
# -----------------
echo "Running Test 2: Local bottom script termination..."

# Run the bottom script
$RUN_SHELL "$BOTTOM_SCRIPT" || fail "local-bottom script failed"

# Verify they are terminated and PID files removed
[ ! -f "$SANDBOX/run/pcscd.pid" ] || fail "pcscd.pid was not cleaned up"
[ ! -f "$SANDBOX/run/gpg-agent.pid" ] || fail "gpg-agent.pid was not cleaned up"

# Give a tiny sleep for process teardown
sleep 0.5
kill -0 "$P_PID" 2>/dev/null && fail "pcscd process was not terminated"
kill -0 "$A_PID" 2>/dev/null && fail "gpg-agent process was not terminated"

# -----------------
# Test 3: Decryption failure terminates daemons immediately
# -----------------
echo "Running Test 3: Decryption failure terminates daemons immediately..."

# Force GPG decrypt failure
touch "$SANDBOX/gpg_decrypt_fail"

# Run decrypt script - it should exit with non-zero
if $RUN_SHELL "$DECRYPT_SCRIPT" "$SANDBOX/key.gpg" 2>/dev/null; then
        fail "decryption script unexpectedly succeeded on failure test"
fi

# Verify everything was cleaned up immediately
[ ! -f "$SANDBOX/run/pcscd.pid" ] || fail "pcscd.pid was not cleaned up on failure"
[ ! -f "$SANDBOX/run/gpg-agent.pid" ] || fail "gpg-agent.pid was not cleaned up on failure"

# Remove force fail flag
rm -f "$SANDBOX/gpg_decrypt_fail"

echo "All tests passed successfully!"
exit 0
