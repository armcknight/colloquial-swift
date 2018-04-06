results_directory = 'github_search_results'
urls_directory = 'ssh_urls'
`mkdir #{urls_directory}`
Dir.entries(results_directory).each do |result_dir|
  next if result_dir == '.' || result_dir == '..' || result_dir == '.DS_Store'
  result_path = "#{results_directory}/#{result_dir}"
  output_path = "#{urls_directory}/#{result_dir}.txt"
  `cat #{result_path}/*.json | jq '.items[] | .ssh_url' | sed s/\\"//g | sort > #{output_path}`
end
