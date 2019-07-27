#!/bin/sh

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project.
hugo

# Go To Public folder
cd public

# Add changes to git.
git add .

# Commit changes.
msg="Update website `date`"
if [ $# -ge 1 ]
	then msg="$*"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin master

# Come Back up to the Project Root
cd ..
