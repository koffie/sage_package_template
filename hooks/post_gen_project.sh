#!/bin/bash
command -v git >/dev/null 2>&1 || { echo >&2 "I require git but it's not installed.  Aborting."; exit 1; }
command -v ssh-keygen >/dev/null 2>&1 || { echo >&2 "I require ssh-keygen but it's not installed.  Aborting."; exit 1; }
command -v travis >/dev/null 2>&1 || { echo >&2 "I require travis (https://github.com/travis-ci/travis.rb) but it's not installed.  Aborting."; exit 1; }

curl -s https://api.github.com/repos/{{cookiecutter.github_username}}/{{cookiecutter.app_name}} | grep "Not Found" || { echo >&2 "The repository {{cookiecutter.app_name}} already exists in {{cookiecutter.github_username}}.  Aborting."; exit 1; }

echo "Trying to create a new repository on github.com."
echo "You will be asked for the GitHub password corresponding to the user {{cookiecutter.github_username}}"
echo "{{cookiecutter.github_username}}/{{cookiecutter.app_name}}"
echo "{{cookiecutter.project_short_description}}"

curl -s -u '{{cookiecutter.github_username}}' https://api.github.com/user/repos -d '{"name":"{{cookiecutter.app_name}}","description":"{{cookiecutter.project_short_description}}"}' >> install.log # Create new repository on github.com

echo "Repository successfully created."
echo ""
echo "Now generating a ECDSA key for Travis-CI doc deployment..."
ssh-keygen -q -t ecdsa -f .travis_ci_gh_pages_deploy_key -N "" # Generate ECDSA key for Travis-CI doc deployment
echo "...done."

echo "Initializing the GitHub repository and pushing changes. You may be asked your GitHub password again..."
git init
git add .
git commit -m "Initial commit" >> install.log
git remote add origin https://github.com/{{cookiecutter.github_username}}/{{cookiecutter.app_name}}.git >> install.log
git push -u origin master >> install.log
echo "Initialization done."

echo "Create a branch to hold the automatically generated documentation. You may be asked your GitHub password again..."
git clone --single-branch --depth 1 https://github.com/{{cookiecutter.github_username}}/{{cookiecutter.app_name}}.git gh-pages
cd gh-pages
git checkout --orphan gh-pages
git rm -rf . >> install.log
touch .nojekyll
git add .nojekyll
git commit -m "Initial commit" >> install.log
git push -u origin gh-pages >> install.log
cd ..
echo "Done with branch creation"


echo "Add deploy public key to GitHub"
filecontents=$(cat .travis_ci_gh_pages_deploy_key.pub)
curl -s -u '{{cookiecutter.github_username}}' https://api.github.com/repos/{{cookiecutter.github_username}}/{{cookiecutter.app_name}}/keys -d "{\"title\":\"Key for deploying documentation to GitHub pages\",\"key\":\"${filecontents}\", \"read_only\":\"false\"}" >> install.log # Add deploy public key to GitHub

echo "Done with public key deployment. You may receive an email from GitHub that lets you know of this."

echo "Next the deploy key will be encrypted for Travis CI to use. Also we will enable the newly created repository in Travis CI."
travis login -u {{cookiecutter.github_username}}
travis encrypt-file .travis_ci_gh_pages_deploy_key --add before_script -r {{cookiecutter.github_username}}/{{cookiecutter.app_name}}
travis enable -r {{cookiecutter.github_username}}/{{cookiecutter.app_name}}
echo "Done!"

echo "Finally we add the encrypted key and commit changes to GitHub. You may be asked for your GitHub password one last time."

git add .travis_ci_gh_pages_deploy_key.enc
git add .travis.yml
git commit -m "Deploy built documentation to GitHub"
git push

echo "Congratulations! The newly created repository is now being tested by Travis CI"
