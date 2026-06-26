#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$SKILLS_DIR"

for skill_dir in "$REPO_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  ln -sfn "$skill_dir" "$SKILLS_DIR/$skill_name"
  echo "Linked: $skill_name"
done

echo "Done. Restart Claude Code to pick up new skills."
