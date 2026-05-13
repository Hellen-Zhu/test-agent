#!/usr/bin/env bash
# Wrapper around `mvn test` that handles Cucumber 4.x tag-expression quoting
# correctly. Pass the tag expression as a single argument.
#
# Examples:
#   scripts/run-by-tag.sh "@smoke and not @wip"
#   scripts/run-by-tag.sh "@story-48217" -Papi
#   scripts/run-by-tag.sh "@regression" -Pnightly --threads 4
#
# Anything after the tag expression is passed through to mvn / cucumber.options.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat <<EOF
Usage: $0 "<tag-expression>" [mvn-args...] [-- <extra-cucumber-args>]

Tag expression must be a Cucumber 4.x expression using or/and/not (NOT commas).

Examples:
  $0 "@smoke and not @wip"                       # default profile (-Pall)
  $0 "@story-48217" -Papi                        # API only
  $0 "@regression" -Pnightly                     # nightly profile
  $0 "@smoke" -Pall -- --threads 4               # extra cucumber args

Profiles available: api, e2e, all (default), smoke, nightly
See references/maven-profiles.md for the full menu.
EOF
  exit 1
fi

TAG_EXPR="$1"
shift

# Reject the common Cucumber-3.x-comma mistake before invoking mvn:
if [[ "$TAG_EXPR" == *","* ]]; then
  cat >&2 <<EOF
ERROR: tag expression contains a comma:
  "$TAG_EXPR"

Cucumber 4.x uses 'or' / 'and' / 'not' keywords, not commas.

Did you mean:
  "$(echo "$TAG_EXPR" | sed 's/,/ or /g')"  ?
EOF
  exit 2
fi

# Split mvn args from cucumber-options pass-through args (anything after `--`)
MVN_ARGS=()
EXTRA_CUKE_ARGS=()
PROFILE_SET=false
SEEN_DASHDASH=false

for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then
    SEEN_DASHDASH=true
    continue
  fi
  if [[ "$SEEN_DASHDASH" == "true" ]]; then
    EXTRA_CUKE_ARGS+=("$arg")
  else
    MVN_ARGS+=("$arg")
    if [[ "$arg" == -P* ]]; then
      PROFILE_SET=true
    fi
  fi
done

# Default to -Pall if no profile specified
if [[ "$PROFILE_SET" == "false" ]]; then
  MVN_ARGS+=("-Pall")
fi

# Build the cucumber.options string. Note the SINGLE quotes around the tag
# expression (required when --tags is parsed by Cucumber 4.x).
CUKE_OPTS="--tags '${TAG_EXPR}'"
for extra in "${EXTRA_CUKE_ARGS[@]:-}"; do
  CUKE_OPTS="${CUKE_OPTS} ${extra}"
done

echo "→ Tag expression: ${TAG_EXPR}"
echo "→ Maven args:     ${MVN_ARGS[*]}"
[[ ${#EXTRA_CUKE_ARGS[@]:-0} -gt 0 ]] && echo "→ Cucumber extra: ${EXTRA_CUKE_ARGS[*]}"
echo

# Use ! to detect mvn failure so we can still print the report path
set +e
mvn test "${MVN_ARGS[@]}" -Dcucumber.options="${CUKE_OPTS}"
EXIT=$?
set -e

# Reports
REPORT_DIR="target/cucumber-reports"
if [[ -d "$REPORT_DIR" ]]; then
  echo
  echo "→ Reports:"
  ls -1t "$REPORT_DIR" | head -5 | sed "s#^#   $REPORT_DIR/#"
fi

exit $EXIT
