require 'json'
require 'set'

# take a list of results in the form 
#
# '   1 "AlbumCollectionNodeController : ASCollectionDelegate"'
#
# and split the count from api name, reverse them, and make them keys/values in a hash:
#
# { "AlbumCollectionNodeController : ASCollectionDelegate" => 1 }
#
def massage_results result_string
  result_hash = Hash.new
  result_string.split("\n").map{|extension_count| # split whole list into individual lines, each containing one extension with its frequency count
    trimmed_components = extension_count.split("\"") # split that one item into the count string and the api name string
    .map {|extension_count_component| # and trim whitespace from the count string and api name string
      extension_count_component.strip
    }
    result_hash[trimmed_components[1]] = trimmed_components[0]
  }
  result_hash
end

all_repositories = Dir.entries('observations').select{|x| x != '.' && x != '..' && x != '.DS_Store'}.map{|x| 'observations/' + x}

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

# do the aggregating on each chunk

aggregations_hash = Hash.new
repo_sets.each_with_index do |repo_set, i|
  # count all extension declarations grouped by uniq
  extensions = massage_results `cat #{repo_set.join(' ')} | jq '.declarations.extension.parsed[].identifier' | sort | uniq -c | sort`

  # count all extension declarations not on Cocoa frameworks (so, no AVFoundation/UIKit/etc); taken from https://nshipster.com/namespacing/
  cocoa_prefixes = [ 'AB', 'AC', 'AD', 'AL', 'AU', 'AV', 'CA', 'CB', 'CF', 'CG', 'CI', 'CL', 'CM', 'CV', 'EA', 'EK', 'GC', 'GLK', 'JS', 'MA', 'MC', 'MF', 'MIDI', 'MK', 'MP', 'NK', 'NS', 'PK', 'QL', 'SC', 'Sec', 'SK', 'SL', 'SS', 'TW', 'UI', 'UT' ]
  
  exclusion_expr = cocoa_prefixes.map{|x| '-e "^\"' + x + '.*"'}.join(' ')
  non_cocoa_touch_extensions = massage_results `cat #{repo_set.join(' ')} | jq '.declarations.extension.parsed[].identifier' | grep -v #{exclusion_expr} | sort | uniq -c | sort`

  # count unique extensions (only 1 declaration found)
  unique_extensions = massage_results(`cat #{repo_set.join(' ')} | jq '.declarations.extension.parsed[].identifier' | sort | uniq -c | sort | grep "   1"`).keys
  
  aggregations_hash[i] = {
    'extensions' => extensions,
    'non_cocoa_touch_extensions' => non_cocoa_touch_extensions,
    'unique_extensions' => unique_extensions,
  }
end

# combine the chunked aggregations
#
# we have a hash like:
#
# { 
#   1 => {
#     'extensions' => { "Some API" => 614, "Other API" => 5 },
#     'non_cocoa_touch_extensions' => { "Some API" => 614, "Other API" => 5 },
#     'unique_extensions' => { "unique api 1", "unique api 2" },  
#   },
#   2 => {
#     'extensions' => { "Other API" => 46, "Yet another API" => 3 },
#     'non_cocoa_touch_extensions' => { "etc" => 2, "et al" => 1 },
#     'unique_extensions' => { "unique api 2", "unique api 3" },  
#   },
# }
# 
# and needs to be combined into one hash
#
# {
#   'extensions' => { "Some API" => 614, "Other API" => 51, "Yet another API" => 3 },
#   'non_cocoa_touch_extensions' => { "Some API" => 614, "Other API" => 5, "etc" => 2, "et al" => 1  },
#   'unique_extensions' => { "unique api 1", "unique api 3" },
# }

all_extensions = Hash.new
all_non_cocoa_touch_extensions = Hash.new
all_unique_extensions = Set.new

aggregations_hash.each do |repo_set, aggregations|
  all_extensions.merge!(aggregations['extensions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
  all_non_cocoa_touch_extensions.merge!(aggregations['non_cocoa_touch_extensions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
  aggregations['unique_extensions'].each {|unique_extension| all_unique_extensions << unique_extension }
end

# write to files

aggregations_dir = 'aggregations'
`mkdir -p #{aggregations_dir}`

File.open("#{aggregations_dir}/extensions.json", 'w') do |file|
  file << JSON.dump(all_extensions)
end

File.open("#{aggregations_dir}/non_cocoa_touch_extensions.json", 'w') do |file|
  file << JSON.dump(all_non_cocoa_touch_extensions)
end

File.open("#{aggregations_dir}/unique_extensions.json", 'w') do |file|
  file << JSON.dump(all_unique_extensions.to_a)
end

# write consolidated, simple text versions of the results

`jq '' #{aggregations_dir}/extensions.json | awk -F'":' '{print $2 $1};' | sort -rn | sed s/\\\"//g | sed s/,//g > #{aggregations_dir}/extensions.simple.txt`
`jq '' #{aggregations_dir}/non_cocoa_touch_extensions.json | awk -F'":' '{print $2 $1};' | sort -rn | sed s/\\\"//g | sed s/,//g > #{aggregations_dir}/non_cocoa_touch_extensions.simple.txt`
