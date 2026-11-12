#!/usr/bin/env bash
# collect_results.sh — gather every real run log into my_results.txt so it can be
# pasted back (Ctrl+A, Ctrl+C) for the documentation. Nothing is edited or invented:
# a section that is missing says "(no ... log)", which means that portfolio did not run.
cd "$(dirname "$0")"
OUT=my_results.txt
: > "$OUT"

section() {   # section "title" file...
  local title="$1"; shift
  echo "################ $title ################" >> "$OUT"
  local any=0
  for f in "$@"; do
    if [ -s "$f" ]; then
      any=1
      echo "---------- $f ----------" >> "$OUT"
      sed 's/\x1b\[[0-9;]*m//g' "$f" >> "$OUT"
      echo >> "$OUT"
    else
      echo "(no $f)" >> "$OUT"
    fi
  done
  [ "$any" = 1 ] || echo "(portfolio did not run: no logs found)" >> "$OUT"
  echo >> "$OUT"
}

echo "Collected on: $(date -u '+%Y-%m-%d %H:%M UTC') in the student's own Codespace" >> "$OUT"
echo >> "$OUT"
section "PORTFOLIO 1 - database design"        p1_output.log
section "PORTFOLIO 2 - query optimisation"     p2_output.log
section "PORTFOLIO 3 - transactions"           p3_output.log
section "PORTFOLIO 4 - MongoDB"                p4_output.log
section "PORTFOLIO 5 - partitioning and replica" p5_output.log

echo "Wrote $OUT ($(wc -l < "$OUT") lines)"
grep -c '^(no \|did not run' "$OUT" | sed 's/^/Missing sections: /'
