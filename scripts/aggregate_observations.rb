all_repositories = Dir.entries('observations').select{|x| x != '.' || x != '..' || x != '.DS_Store'}.map{|x| 'observations/' + x}

# chunk up the set of repos to process so `jq` doesn't run out of memory
stride = 500
start_i = 0
end_i = stride - 1
repo_count = all_repositories.size
repo_sets = Array.new
while start_i < repo_count do
  end_i = repo_count - 1 if end_i >= repo_count
  next_set = all_repositories[start_i..end_i]
  repo_sets << next_set
  start_i = end_i + 1
  end_i += stride
end

repo_sets.each do |repo_set|
  # count all extension declarations grouped by uniq
  extensions = `jq '.declarations.extension.parsed[].identifier' #{repo_set} | sort | uniq -c | sort`

  # count all extension declarations not on Cocoa frameworks (so, no AVFoundation/UIKit/etc)
  cocoa_prefixes = ['UI', 'NS', 'CG', 'CI', 'CL', 'MK', 'AV', 'CA']
  exclusion_expr = cocoa_prefixes.map{|x| -e "^#{x}.*"}.join(' ')
  non_cocoa_extensions = `jq '.declarations.extension.parsed[].identifier' observations/*.json | sed s/\"//g | grep -v #{exclusion_expr} | sort | uniq -c | sort`

  # count unique extensions (only 1 declaration found)
  unique_extensions = `jq '.declarations.extension.parsed[].identifier' observations/*.json | sort | uniq -c | sort | grep "   1" | wc -l`
end
