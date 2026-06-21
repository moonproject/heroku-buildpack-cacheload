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

# --- Test 3: Multiple literal file paths ---
echo "=== Test 3: Multiple literal file paths ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
README.md
NOTES.md
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/README.md"
assert_exists "${BUILD_DIR}/NOTES.md"
assert_not_exists "${BUILD_DIR}/app.js"

# --- Test 4: Inclusion globs are treated literally (not expanded) ---
echo "=== Test 4: Inclusion globs are not expanded ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
*.js
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
# A literal "*.js" file does not exist in the cache, so nothing is restored.
assert_not_exists "${BUILD_DIR}/app.js"
assert_not_exists "${BUILD_DIR}/util.js"

# --- Test 5: Negation ---
echo "=== Test 5: Negation with ! ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
app.js
util.js
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

# --- Test 7: Deep glob with ** in negation ---
echo "=== Test 7: Deep glob with ** in negation ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
node_modules
code/server/node_modules
!**/node_modules
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_not_exists "${BUILD_DIR}/node_modules"
assert_not_exists "${BUILD_DIR}/code/server/node_modules"

# --- Test 8: Directory path with trailing slash ---
echo "=== Test 8: Directory path with trailing slash ==="
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
README.md
NOTES.md
app.js
util.js
!*.md
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/app.js"
assert_exists "${BUILD_DIR}/util.js"
assert_not_exists "${BUILD_DIR}/README.md"
assert_not_exists "${BUILD_DIR}/NOTES.md"

# --- Test 10: Many paths restored in parallel ---
echo "=== Test 10: Many paths restored in parallel ==="
setup_cache; reset_build
for i in $(seq 1 30); do
  echo "data${i}" > "${CACHE_ROOT}/file${i}.dat"
done
touch "${BUILD_DIR}/.buildcache"
for i in $(seq 1 30); do
  echo "file${i}.dat" >> "${BUILD_DIR}/.buildcache"
done
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
for i in $(seq 1 30); do
  assert_exists "${BUILD_DIR}/file${i}.dat"
done

# --- Test 11: Literal negation inside a restored directory ---
echo "=== Test 11: Literal negation inside a restored directory ==="
setup_cache; reset_build
cat > "${BUILD_DIR}/.buildcache" << EOF
node_modules
!node_modules/lodash
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/node_modules/express/index.js"
assert_not_exists "${BUILD_DIR}/node_modules/lodash"

# --- Test 12: Glob negation inside a restored directory ---
echo "=== Test 12: Glob negation inside a restored directory ==="
setup_cache; reset_build
mkdir -p "${CACHE_ROOT}/node_modules/express/cache"
echo "log" > "${CACHE_ROOT}/node_modules/express/cache/debug.log"
cat > "${BUILD_DIR}/.buildcache" << EOF
node_modules
!**/*.log
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
assert_exists "${BUILD_DIR}/node_modules/express/index.js"
assert_not_exists "${BUILD_DIR}/node_modules/express/cache/debug.log"

# --- Test 13: Negation never removes non-restored build files ---
echo "=== Test 13: Negation never removes non-restored build files ==="
setup_cache; reset_build
echo "source" > "${BUILD_DIR}/keep.md"
cat > "${BUILD_DIR}/.buildcache" << EOF
README.md
!*.md
EOF
bash "${COMPILE}" "${BUILD_DIR}" "${CACHE_DIR}" 2>&1
# README.md was restored then removed by the negation; keep.md was never
# restored from cache, so it must be left untouched.
assert_not_exists "${BUILD_DIR}/README.md"
assert_exists "${BUILD_DIR}/keep.md"

# --- Cleanup ---
rm -rf "${TESTDIR}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ ${FAIL} -gt 0 ]; then
  echo -e "Failures:${ERRORS}"
  exit 1
fi
exit 0
