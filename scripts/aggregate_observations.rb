require 'json'

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

aggregations_hash = Hash.new
repo_sets.each_with_index do |repo_set, i|
  # count all extension declarations grouped by uniq
  extensions = massage_results `cat #{repo_set.join(' ')} | jq '.declarations.extension.parsed[].identifier' | sort | uniq -c | sort`

  # count all extension declarations not on Cocoa frameworks (so, no AVFoundation/UIKit/etc)
  cocoa_prefixes = ['UI', 'NS', 'CG', 'CI', 'CL', 'MK', 'AV', 'CA']
  exclusion_expr = cocoa_prefixes.map{|x| "-e ^#{x}.*"}.join(' ')
  non_cocoa_extensions = massage_results `cat #{repo_set.join(' ')} | jq '.declarations.extension.parsed[].identifier' | grep -v #{exclusion_expr} | sort | uniq -c | sort`

  # count unique extensions (only 1 declaration found)
  unique_extensions_count = massage_results(`cat #{repo_set.join(' ')} | jq '.declarations.extension.parsed[].identifier' | sort | uniq -c | sort | grep "   1"`).keys
  
  aggregations_hash[i] = {
    'extensions' => extensions,
    'non_cocoa_extensions' => non_cocoa_extensions,
    'unique_extensions_count' => unique_extensions_count,
  }
end

aggregations_dir = 'aggregations'
`mkdir -p #{aggregations_dir}`
aggregations_hash.each do |repo_set, aggregations|
  File.open("#{aggregations_dir}/#{repo_set}.json", 'w') do |file|
    file << JSON.dump(aggregations)
  end
end
