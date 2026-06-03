#!/bin/bash

set -euo pipefail
# How to use
# ./migrate_grafana_dashboards.sh http://old_url OLD_API_KEY http://new_url NEW_API_KEY ./staging false
# =========================================================
# INPUTS
# =========================================================
OLD_URL="$1"
OLD_KEY="$2"

NEW_URL="$3"
NEW_KEY="$4"

STAGING_DIR="${5:-./tmp/staging}"
DRY_RUN="${6:-true}"

LOG_FILE="./grafana_migration.log"

mkdir -p "$STAGING_DIR"

echo "====================================" | tee "$LOG_FILE"
echo "Grafana Migration (SAFE DEFAULT MODE)" | tee -a "$LOG_FILE"
echo "OLD: $OLD_URL" | tee -a "$LOG_FILE"
echo "NEW: $NEW_URL" | tee -a "$LOG_FILE"
echo "STAGING: $STAGING_DIR" | tee -a "$LOG_FILE"
echo "DRY RUN: $DRY_RUN" | tee -a "$LOG_FILE"
echo "====================================" | tee -a "$LOG_FILE"

OLD_AUTH="Authorization: Bearer $OLD_KEY"
NEW_AUTH="Authorization: Bearer $NEW_KEY"

# =========================================================
# STEP 1: EXPORT
# =========================================================
echo "STEP 1: Export dashboards..." | tee -a "$LOG_FILE"

curl -s -H "$OLD_AUTH" \
  "$OLD_URL/api/search?type=dash-db" |
jq -c '.[]' |
while read -r dash; do

  DASH_UID=$(echo "$dash" | jq -r '.uid')
  DASH_TITLE=$(echo "$dash" | jq -r '.title')

  SAFE_TITLE=$(echo "$DASH_TITLE" | tr ' /:\\"*?<>|' '__________' | tr ' ' '_')
  FILE="$STAGING_DIR/${SAFE_TITLE}.json"

  echo "Export: $DASH_TITLE ($DASH_UID)" | tee -a "$LOG_FILE"

  curl -s -H "$OLD_AUTH" \
    "$OLD_URL/api/dashboards/uid/$DASH_UID" |
  jq '.dashboard' > "$FILE"

done

echo "Export done." | tee -a "$LOG_FILE"

# =========================================================
# STEP 2: FOLDER HANDLING
# =========================================================
get_folder_id() {
  local title="$1"

  if [[ -z "$title" || "$title" == "General" ]]; then
    echo 0
    return
  fi

  existing=$(curl -s -H "$NEW_AUTH" \
    "$NEW_URL/api/folders" |
    jq -r --arg t "$title" '.[] | select(.title==$t) | .id')

  if [[ -n "$existing" ]]; then
    echo "$existing"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo 0
    return
  fi

  res=$(curl -s -X POST "$NEW_URL/api/folders" \
    -H "$NEW_AUTH" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"$title\"}")

  echo "$res" | jq -r '.id'
}

# =========================================================
# STEP 3: STRIP DATASOURCE (IMPORTANT FIX)
# =========================================================
strip_datasource() {
  local file="$1"

  jq '
    walk(
      if type == "object" and has("datasource") then
        del(.datasource)
      else
        .
      end
    )
  ' "$file"
}

# =========================================================
# STEP 4: IMPORT
# =========================================================
echo "STEP 2: Import dashboards..." | tee -a "$LOG_FILE"

for file in "$STAGING_DIR"/*.json; do
  [[ -e "$file" ]] || continue

  echo "--------------------------------" | tee -a "$LOG_FILE"
  echo "Importing: $file" | tee -a "$LOG_FILE"

  DASH_TITLE=$(jq -r '.title' "$file")

  FOLDER_TITLE=$(jq -r '.folderTitle // "General"' "$file")
  FOLDER_ID=$(get_folder_id "$FOLDER_TITLE")

  if [[ "$FOLDER_ID" == "0" ]]; then
    FOLDER_ID=null
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN OK: $DASH_TITLE" | tee -a "$LOG_FILE"
    continue
  fi

  RESPONSE_FILE=$(mktemp)

  # 🔥 IMPORTANT: remove ALL datasource definitions
  MODIFIED=$(strip_datasource "$file")

  HTTP_CODE=$(
    echo "$MODIFIED" |
    jq '
      . as $d |
      {
        dashboard: ($d | del(.id) | .id = null),
        folderId: '"$FOLDER_ID"',
        overwrite: true
      }
    ' |
    curl -s -o "$RESPONSE_FILE" -w "%{http_code}" \
      -X POST "$NEW_URL/api/dashboards/db" \
      -H "$NEW_AUTH" \
      -H "Content-Type: application/json" \
      --data-binary @-
  )

  RESPONSE_BODY=$(cat "$RESPONSE_FILE")
  rm -f "$RESPONSE_FILE"

  echo "HTTP: $HTTP_CODE" | tee -a "$LOG_FILE"
  echo "Response: $RESPONSE_BODY" | tee -a "$LOG_FILE"

  STATUS=$(echo "$RESPONSE_BODY" | jq -r '.status // empty')
  MESSAGE=$(echo "$RESPONSE_BODY" | jq -r '.message // empty')

  if [[ "$HTTP_CODE" == "200" && "$STATUS" == "success" ]]; then
    echo "OK: $DASH_TITLE" | tee -a "$LOG_FILE"
  else
    echo "FAIL: $DASH_TITLE | $MESSAGE" | tee -a "$LOG_FILE"
  fi

done

echo "====================================" | tee -a "$LOG_FILE"
echo "MIGRATION FINISHED" | tee -a "$LOG_FILE"
