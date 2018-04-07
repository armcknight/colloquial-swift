results_directory = 'github_search_results'

Dir.entries(results_directory).each do |result_dir|
  next if result_dir == '.' || result_dir == '..' || result_dir == '.DS_Store'
  result_file_path = "#{results_directory}/#{result_dir}/1.json"
  count = `jq '.total_count' #{result_file_path}`
  puts "#{result_dir}: #{count}"
end

total = `cat ssh_urls/*.txt | wc -l`
uniques = `cat ssh_urls/*.txt | sort | uniq | wc -l`
puts "total: #{total.strip}"
puts "unique: #{uniques.strip}"
