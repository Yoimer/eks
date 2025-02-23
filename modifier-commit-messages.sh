#!/bin/bash

# Define original commit messages with short SHAs
declare -A original_commit_messages=(
  ["b6dfefa"]="Rename troubleshooting file to 'troubleshooting-vpc-cni-error.md' and add comments in 'readme.md'"
  ["8b5aca2"]="Add initial 'readme.md' with project overview and setup instructions"
  ["a914121"]="Reorganize 'summary.md' for better structure and readability"
  ["26f910d"]="Document readiness and liveness probe issues in 'troubleshooting.md'"
  ["089ab06"]="Add Step 1: Inspect image using 'docker export' in troubleshooting guide"
  ["1a3ac24"]="Add 'What to Expect' section in troubleshooting guide"
  ["f3327f7"]="Introduce first part of Docker troubleshooting guide"
  ["0e35037"]="Add initial 'troubleshooting.md' for EKS-related issues"
  ["c2ed7c3"]="Fix formatting inconsistencies in 'summary.md'"
  ["dd8c8d6"]="Expand explanation of annotation usage in EKS"
  ["90aef6c"]="Fix typo in 'summary.md'"
  ["5d19b74"]="Correct formatting issues in 'summary.md'"
  ["4d0a77c"]="Add missing OIDC provider creation step"
  ["302c903"]="Fix typo in 'summary.md'"
  ["44829af"]="Include suggested IRSA role name for clarity"
  ["596d218"]="Add real-life example for OIDC IAM trusted policy"
  ["cca59c1"]="Fix wording in EKS policy for better clarity"
  ["550400e"]="Update 'summary.md' with more meaningful and expressive emojis"
  ["0e38f2f"]="Initialize repository with minimal EKS cluster configuration using 'eksctl'"
)

# Convert short SHAs to full SHAs
declare -A commit_messages
for short_sha in "${!original_commit_messages[@]}"; do
    # Resolve short SHA to full SHA
    full_sha=$(git rev-parse "$short_sha")
    commit_messages["$full_sha"]="${original_commit_messages[$short_sha]}"
done
unset original_commit_messages

# Generate temporary msg-filter script with commit messages
tempfile=$(mktemp)
cat > "$tempfile" <<EOF
#!/bin/bash
declare -A commit_messages=(
EOF

# Populate commit messages into temporary script
for sha in "${!commit_messages[@]}"; do
    # Escape double quotes in the message
    msg="${commit_messages[$sha]}"
    escaped_msg=$(printf '%s' "$msg" | sed 's/"/\\"/g')
    echo "  [\"$sha\"]=\"$escaped_msg\"" >> "$tempfile"
done

# Complete the temporary script
cat >> "$tempfile" <<EOF
)
sha=\$GIT_COMMIT
if [[ -n "\${commit_messages[\$sha]}" ]]; then
    printf "%s" "\${commit_messages[\$sha]}"
else
    cat
fi
EOF

# Make the temporary script executable
chmod +x "$tempfile"

# Rewrite commit history with new messages
git filter-branch -f --msg-filter "$tempfile" main

# Cleanup
rm "$tempfile"

# Output success message
echo "Commit messages have been successfully updated!"