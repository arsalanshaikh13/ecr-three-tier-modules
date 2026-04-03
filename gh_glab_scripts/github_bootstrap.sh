#!/bin/bash
# Usage: ./bootstrap.sh my-new-app
REPO_NAME="ecr-three-tier-modules"
# source .env
GH_USER="arsalanshaikh13"
echo "🚀 Bootstrapping $REPO_NAME..."

# 1. Create GH Repo
# gh repo create "$GH_USER/$REPO_NAME" --private
# gh repo create "$GH_USER/$REPO_NAME" --public
# # to browse files on browser
# gh repo view "$GH_USER/$REPO_NAME" --web 
# gh api repos/$GH_USER/$REPO_NAME/contents 
#for a terminal-based list.
# To download the code: Run to create a local copy.
# gh repo clone "$GH_USER/$REPO_NAME"
 

# 2. Set AWS Environment Variables (Repo Level)
# gh variable set ENV_VAR --body "dev" --repo "$GH_USER/$REPO_NAME"
# gh variable set ACCOUNT_ID --body "750702272407" --repo "$GH_USER/$REPO_NAME"
gh variable set PROJECT_NAME --body "lirw-ecs" --repo "$GH_USER/$REPO_NAME"

# 3. Create 'production' Environment & Secrets
# echo "Creating production env..."
# gh api --method PUT "repos/$GH_USER/$REPO_NAME/environments/production"

# gh secret set AWS_ACCESS_KEY --body "AKIA..." --repo "$GH_USER/$REPO_NAME" --env production

# 4. Initialize Local Git
# git init 
# git add .
# git commit -m "Initial commit from bootstrapper"
# git branch -M main
# git remote add origin "git@github.com:$GH_USER/$REPO_NAME.git"

echo "✅ Ready to push! Just run 'git push -u origin main'"
