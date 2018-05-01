bundle
brew install ag jq

pushd scripts

ruby github_search_queries.rb
ruby gather_ssh_urls.rb
ruby clone_repos.rb
ruby remove_dependencies_and_examples.rb
ruby filter_for_podspecs.rb
ruby observe.rb

popd
