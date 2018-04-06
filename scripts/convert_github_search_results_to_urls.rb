results_directory = 'github_search_results'

Dir.entries(results_directory).each do |result_dir|
  next if result_dir == '.' || result_dir == '..' || result_dir == '.DS_Store'
  path = "#{results_directory}/#{result_dir}"
  `cat #{path}/*.json | jq '.items[] | .ssh_url' > #{path}/urls.txt`
end