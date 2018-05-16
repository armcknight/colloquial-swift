bundle
brew install ag jq

ruby scripts/github_search_queries.rb
ruby scripts/get_search_result_counts.rb
bash scripts/combine_search_results.sh
ruby scripts/gather_ssh_urls.rb
ruby scripts/clone_repos.rb
ruby scripts/remove_dependencies_and_examples.rb
ruby scripts/filter_for_podspecs.rb
ruby scripts/parse_asts.rb
ruby scripts/observe.rb
