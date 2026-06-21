#!/usr/bin/env bash

# Test suite for bin/compile – validates .gitignore-like .buildcache behaviour.

PASS=0
FAIL=0
ERRORS=""

assert_exists() {
  if [ -e "$1" ]; then
    echo "  PASS: $1 exists"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1 should exist but doesn't"
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $1 should exist"
  fi
}

assert_not_exists() {
  if ! [ -e "$1" ]; then
    echo "  PASS: $1 does not exist (as expected)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1 should NOT exist but does"
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $1 should NOT exist"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILE="${SCRIPT_DIR}/../bin/compile"

# --- Setup helpers ---
TESTDIR=$(mktemp -d)
BUILD_DIR="${TESTDIR}/build"
CACHE_DIR="${TESTDIR}/cache"
CACHE_ROOT="${CACHE_DIR}/buildcache"

setup_cache() {
  rm -rf "${CACHE_ROOT}"
  mkdir -p "${CACHE_ROOT}"
  mkdir -p "${CACHE_ROOT}/node_modules/express"
  echo "express" > "${CACHE_ROOT}/node_modules/express/index.js"
  mkdir -p "${CACHE_ROOT}/node_modules/lodash"
  echo "lodash" > "${CACHE_ROOT}/node_modules/lodash/index.js"
  mkdir -p "${CACHE_ROOT}/code/server/node_modules/pkg"
  echo "pkg" > "${CACHE_ROOT}/code/server/node_modules/pkg/index.js"
  echo "config" > "${CACHE_ROOT}/config.json"
  echo "readme" > "${CACHE_ROOT}/README.md"
  echo "notes" > "${CACHE_ROOT}/NOTES.md"
  echo "app" > "${CACHE_ROOT}/app.js"
  echo "util" > "${CACHE_ROOT}/util.js"
  mkdir -p "${CACHE_ROOT}/assets"
  echo "logo" > "${CACHE_ROOT}/assets/logo.png"
  echo "style" > "${CACHE_ROOT}/assets/style.css"
  mkdir -p "${CACHE_ROOT}/lib"
  echo "helper" > "${CACHE_ROOT}/lib/helper.js"
}

reset_build() {
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}"
}

# --- Test 1: Literal path ---
echo "=== Test 1: Literal path ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
config.json
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/config.json"
assert_not_exists "${BUILD_DIR}/app.js"

# --- Test 2: Directory path ---
echo "=== Test 2: Directory path ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
node_modules
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/node_modules/express/index.js"
assert_exists "${BUILD_DIR}/node_modules/lodash/index.js"

# --- Test 3: Glob pattern *.md ---
echo "=== Test 3: Glob pattern (*.md) ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
*.md
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/README.md"
assert_exists "${BUILD_DIR}/NOTES.md"
assert_not_exists "${BUILD_DIR}/app.js"

# --- Test 4: Glob pattern *.js ---
echo "=== Test 4: Glob pattern (*.js) ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
*.js
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/app.js"
assert_exists "${BUILD_DIR}/util.js"
assert_not_exists "${BUILD_DIR}/config.json"

# --- Test 5: Negation ---
echo "=== Test 5: Negation with ! ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
*.js
!util.js
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/app.js"
assert_not_exists "${BUILD_DIR}/util.js"

# --- Test 6: Comments and empty lines ---
echo "=== Test 6: Comments and empty lines ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
# This is a comment
config.json

# Another comment
app.js
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/config.json"
assert_exists "${BUILD_DIR}/app.js"
assert_not_exists "${BUILD_DIR}/util.js"

# --- Test 7: Deep glob with ** ---
echo "=== Test 7: Deep glob with ** ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
**/node_modules
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/node_modules"
assert_exists "${BUILD_DIR}/code/server/node_modules"

# --- Test 8: Directory-only trailing slash ---
echo "=== Test 8: Directory-only trailing slash ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
assets/
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/assets"
assert_not_exists "${BUILD_DIR}/config.json"

# --- Test 9: Negation with glob ---
echo "=== Test 9: Negation with glob ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
*.md
*.js
!*.md
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/app.js"
assert_not_exists "${BUILD_DIR}/README.md"
assert_not_exists "${BUILD_DIR}/NOTES.md"

# --- Cleanup ---
rm -rf "${TESTDIR}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ ${FAIL} -gt 0 ]; then
  echo -e "Failures:${ERRORS}"
  exit 1
fi
exit 0
