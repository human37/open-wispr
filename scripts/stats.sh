#!/usr/bin/env bash
set -euo pipefail

REPO="human37/open-wispr"
W=60

bar() {
  local val=$1 max=$2 width=$3
  if [ "$max" -eq 0 ]; then printf '%*s' "$width" ""; return; fi
  local len=$(( val * width / max ))
  [ "$len" -eq 0 ] && [ "$val" -gt 0 ] && len=1
  local bar_str=""
  for (( j=0; j<len; j++ )); do bar_str+="█"; done
  printf '%s%*s' "$bar_str" $(( width - len )) ""
}

row() {
  local label=$1 label_w=$2 bar_w=$3 val=$4 max=$5
  local b
  b=$(bar "$val" "$max" "$bar_w")
  printf '║  %-*s %s %*s  ║\n' "$label_w" "$label" "$b" 4 "$val"
}

header() {
  local title="$1"
  local pad=$(( (W - ${#title}) / 2 ))
  printf '╔%s╗\n' "$(printf '═%.0s' $(seq 1 $W))"
  printf '║%*s%s%*s║\n' "$pad" "" "$title" $(( W - pad - ${#title} )) ""
  printf '╠%s╣\n' "$(printf '═%.0s' $(seq 1 $W))"
}

blank() { printf '║%*s║\n' $W ""; }

footer() {
  local label="$1"
  printf '║%*s%s  ║\n' $(( W - ${#label} - 2 )) "" "$label"
  printf '╚%s╝\n' "$(printf '═%.0s' $(seq 1 $W))"
}

close() { printf '╚%s╝\n' "$(printf '═%.0s' $(seq 1 $W))"; }

echo ""

# --- Repo overview ---
read -r stars forks watchers issues created < <(
  gh api "repos/$REPO" --jq '[.stargazers_count, .forks_count, .subscribers_count, .open_issues_count, .created_at[:10]] | join(" ")'
)
latest_tag=$(gh api "repos/$REPO/releases" --jq '.[0].tag_name // "none"')

header "OVERVIEW"
blank
printf '║  Created: %-10s  Stars: %-5s  Forks: %-14s  ║\n' "$created" "$stars" "$forks"
printf '║  Latest:  %-10s  Issues: %-4s  Watchers: %-11s  ║\n' "$latest_tag" "$issues" "$watchers"
blank
close
echo ""

# --- Bottle downloads ---
declare -a dl_tags=() dl_counts=()
dl_max=0 dl_total=0
while IFS=' ' read -r tag count; do
  dl_tags+=("$tag")
  dl_counts+=("$count")
  dl_total=$(( dl_total + count ))
  [ "$count" -gt "$dl_max" ] && dl_max=$count
done < <(gh api "repos/$REPO/releases" --jq '.[] | "\(.tag_name) \([.assets[].download_count] | add // 0)"')

header "BOTTLE DOWNLOADS (by release)"
blank
for i in "${!dl_tags[@]}"; do
  row "${dl_tags[$i]}" 8 42 "${dl_counts[$i]}" "$dl_max"
done
blank
footer "Total: $dl_total"
echo ""

# --- Git clones ---
declare -a cl_dates=() cl_counts=()
cl_max=0 cl_total=0
while IFS=' ' read -r date count; do
  cl_dates+=("$date")
  cl_counts+=("$count")
  cl_total=$(( cl_total + count ))
  [ "$count" -gt "$cl_max" ] && cl_max=$count
done < <(gh api "repos/$REPO/traffic/clones" --jq '.clones[] | "\(.timestamp[:10]) \(.count)"')

header "GIT CLONES (last 14 days)"
blank
for i in "${!cl_dates[@]}"; do
  day=$(date -j -f "%Y-%m-%d" "${cl_dates[$i]}" "+%b %d" 2>/dev/null || echo "${cl_dates[$i]:5}")
  row "$day" 7 43 "${cl_counts[$i]}" "$cl_max"
done
blank
footer "Total: $cl_total"
echo ""

# --- Page views ---
declare -a pv_dates=() pv_counts=()
pv_max=0 pv_total=0
while IFS=' ' read -r date count; do
  pv_dates+=("$date")
  pv_counts+=("$count")
  pv_total=$(( pv_total + count ))
  [ "$count" -gt "$pv_max" ] && pv_max=$count
done < <(gh api "repos/$REPO/traffic/views" --jq '.views[] | "\(.timestamp[:10]) \(.count)"')

header "PAGE VIEWS (last 14 days)"
blank
for i in "${!pv_dates[@]}"; do
  day=$(date -j -f "%Y-%m-%d" "${pv_dates[$i]}" "+%b %d" 2>/dev/null || echo "${pv_dates[$i]:5}")
  row "$day" 7 43 "${pv_counts[$i]}" "$pv_max"
done
blank
footer "Total: $pv_total"
echo ""

# --- Referrers ---
declare -a ref_names=() ref_counts=()
ref_max=0
while IFS=' ' read -r name count; do
  ref_names+=("$name")
  ref_counts+=("$count")
  [ "$count" -gt "$ref_max" ] && ref_max=$count
done < <(gh api "repos/$REPO/traffic/popular/referrers" --jq '.[] | "\(.referrer) \(.count)"')

if [ ${#ref_names[@]} -gt 0 ]; then
  header "TOP REFERRERS (last 14 days)"
  blank
  for i in "${!ref_names[@]}"; do
    row "${ref_names[$i]}" 20 30 "${ref_counts[$i]}" "$ref_max"
  done
  blank
  close
  echo ""
fi

# --- Popular pages ---
declare -a pp_paths=() pp_counts=()
pp_max=0
while IFS=' ' read -r path count; do
  short="${path#/human37/open-wispr}"
  [ -z "$short" ] && short="/"
  pp_paths+=("$short")
  pp_counts+=("$count")
  [ "$count" -gt "$pp_max" ] && pp_max=$count
done < <(gh api "repos/$REPO/traffic/popular/paths" --jq '.[] | "\(.path) \(.count)"')

if [ ${#pp_paths[@]} -gt 0 ]; then
  header "POPULAR PAGES (last 14 days)"
  blank
  for i in "${!pp_paths[@]}"; do
    display="${pp_paths[$i]}"
    [ ${#display} -gt 25 ] && display="...${display: -22}"
    row "$display" 25 25 "${pp_counts[$i]}" "$pp_max"
  done
  blank
  close
  echo ""
fi
