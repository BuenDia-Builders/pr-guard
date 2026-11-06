#!/usr/bin/env bash
set -euo pipefail

mkdir -p pr-guard-report

if [ -z "${PR_AUTHOR:-}" ]; then
  echo "No hay contexto de pull_request, se omite el risk score."
  echo '{"skipped": true}' > pr-guard-report/report.json
  exit 0
fi

user_json=$(gh api "users/$PR_AUTHOR")
created_at=$(echo "$user_json" | jq -r '.created_at')
public_repos=$(echo "$user_json" | jq -r '.public_repos')

created_epoch=$(date -d "$created_at" +%s)
now_epoch=$(date +%s)
account_age_days=$(( (now_epoch - created_epoch) / 86400 ))

repos_json=$(gh api "users/$PR_AUTHOR/repos?per_page=100&type=owner" --paginate)
fork_count=$(echo "$repos_json" | jq '[.[] | select(.fork == true)] | length')
original_count=$(echo "$repos_json" | jq '[.[] | select(.fork == false)] | length')

prior_prs=$(gh api "search/issues?q=repo:$REPO+author:$PR_AUTHOR+type:pr" --jq '.total_count')

score=0
reasons=()

if [ "$account_age_days" -lt 30 ]; then
  score=$((score + 2))
  reasons+=("cuenta creada hace $account_age_days dias")
fi

if [ "$fork_count" -gt 15 ] && [ "$original_count" -le 1 ]; then
  score=$((score + 3))
  reasons+=("$fork_count forks propios vs $original_count repos originales (patron de mass-forking)")
fi

if [ "$prior_prs" -le 1 ]; then
  score=$((score + 1))
  reasons+=("primera contribucion de este autor a este repo")
fi

level="bajo"
if [ "$score" -ge 3 ] && [ "$score" -lt 5 ]; then
  level="medio"
fi
if [ "$score" -ge 5 ]; then
  level="ALTO"
fi

{
  echo "### pr-guard: riesgo del contribuyente"
  echo ""
  echo "**Autor:** @$PR_AUTHOR &nbsp;·&nbsp; **Riesgo:** $level (score $score)"
  echo ""
  if [ "${#reasons[@]}" -gt 0 ]; then
    echo "Senales detectadas:"
    for r in "${reasons[@]}"; do
      echo "- $r"
    done
  else
    echo "Sin senales de riesgo en el perfil del autor."
  fi
  echo ""
  echo "_Esto es una heuristica sobre el perfil del autor, no un veredicto sobre el codigo. Revisa igual el diff completo, en particular \`package.json\`, lockfiles y \`.github/workflows/\`._"
} > pr-guard-report/comment.md

jq -n \
  --arg author "$PR_AUTHOR" \
  --argjson score "$score" \
  --arg level "$level" \
  --argjson account_age_days "$account_age_days" \
  --argjson public_repos "$public_repos" \
  --argjson fork_count "$fork_count" \
  --argjson original_count "$original_count" \
  --argjson prior_prs "$prior_prs" \
  --argjson pr_number "$PR_NUMBER" \
  '{author: $author, score: $score, level: $level, account_age_days: $account_age_days, public_repos: $public_repos, fork_count: $fork_count, original_count: $original_count, prior_prs: $prior_prs, pr_number: $pr_number}' \
  > pr-guard-report/report.json

echo "Risk score: $score ($level)"
