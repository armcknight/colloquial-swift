require 'json'
require 'set'

# take a list of results from e.g. `jq ... | sort | uniq -c` of the form 
#
# '   1 "AlbumCollectionNodeController : ASCollectionDelegate"'
#
# and split the count from api name, reverse them, and make them keys/values in a hash:
#
# { "AlbumCollectionNodeController : ASCollectionDelegate" => 1 }
#
def massage_counted_uniqued_results result_string
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
  observation_files = repo_set.join(' ')
    
  # count all extension declarations grouped by uniq
  extensions = massage_counted_uniqued_results `cat #{observation_files} | jq '.declarations.extension.parsed[].identifier' | sort | uniq -c | sort`

  # count all extension declarations not on Cocoa frameworks (so, no AVFoundation/UIKit/etc); taken from https://nshipster.com/namespacing/
  cocoa_prefixes = [ 'AB', 'AC', 'AD', 'AL', 'AU', 'AV', 'CA', 'CB', 'CF', 'CG', 'CI', 'CL', 'CM', 'CV', 'EA', 'EK', 'GC', 'GLK', 'JS', 'MA', 'MC', 'MF', 'MIDI', 'MK', 'MP', 'NK', 'NS', 'PK', 'QL', 'SC', 'Sec', 'SK', 'SL', 'SS', 'TW', 'UI', 'UT' ]
  
  exclusion_expr = cocoa_prefixes.map{|x| '-e "^\"' + x + '.*"'}.join(' ')
  non_cocoa_extensions = massage_counted_uniqued_results `cat #{observation_files} | jq '.declarations.extension.parsed[].identifier' | grep -v #{exclusion_expr} | sort | uniq -c | sort`

  # count unique extensions (only 1 declaration found)
  unique_extensions = massage_counted_uniqued_results(`cat #{observation_files} | jq '.declarations.extension.parsed[].identifier' | sort | uniq -c | sort | grep "   1"`).keys
  
  aggregations_hash[i] = {
    'extensions' => extensions,
    'non_cocoa_extensions' => non_cocoa_extensions,
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
#     'non_cocoa_extensions' => { "Some API" => 614, "Other API" => 5 },
#     'unique_extensions' => { "unique api 1", "unique api 2" },  
#   },
#   2 => {
#     'extensions' => { "Other API" => 46, "Yet another API" => 3 },
#     'non_cocoa_extensions' => { "etc" => 2, "et al" => 1 },
#     'unique_extensions' => { "unique api 2", "unique api 3" },  
#   },
# }
# 
# and needs to be combined into one hash
#
# {
#   'extensions' => { "Some API" => 614, "Other API" => 51, "Yet another API" => 3 },
#   'non_cocoa_extensions' => { "Some API" => 614, "Other API" => 5, "etc" => 2, "et al" => 1  },
#   'unique_extensions' => { "unique api 1", "unique api 3" },
# }

all_extensions = Hash.new
all_non_cocoa_extensions = Hash.new
all_unique_extensions = Set.new

aggregations_hash.each do |repo_set_i, aggregations|
  all_extensions.merge!(aggregations['extensions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
  all_non_cocoa_extensions.merge!(aggregations['non_cocoa_extensions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
  aggregations['unique_extensions'].each {|unique_extension| all_unique_extensions << unique_extension }
end

# write to files

aggregations_dir = 'aggregations'
`mkdir -p #{aggregations_dir}`
File.open("#{aggregations_dir}/extensions.json", 'w') do |file|
  file << JSON.dump(all_extensions)
end
File.open("#{aggregations_dir}/non_cocoa_extensions.json", 'w') do |file|
  file << JSON.dump(all_non_cocoa_extensions)
end
File.open("#{aggregations_dir}/unique_extensions.json", 'w') do |file|
  file << JSON.dump(all_unique_extensions.to_a)
end
File.open("#{aggregations_dir}/_stats.json", 'w') do |file|
  file << JSON.dump({
    'total_apis_extended' => all_extensions.size,
    'non_cocoa_apis_extended' => all_non_cocoa_extensions.size,
    'unique_extension_declarations' => all_unique_extensions.size,
  })
end

# write consolidated, simple text versions of the results

remove_first_comma = 'sed s/,//1'
remove_double_quotes = "sed s/\\\"//g"
simple_extensions = `jq '' #{aggregations_dir}/extensions.json | awk -F'":' '{print $2 $1};' | sort -rn | #{remove_double_quotes} | #{remove_first_comma} | tee #{aggregations_dir}/extensions.simple.txt`.split("\n")
simple_non_cocoa_extensions = `jq '' #{aggregations_dir}/non_cocoa_extensions.json | awk -F'":' '{print $2 $1};' | sort -rn | #{remove_double_quotes} | #{remove_first_comma} | tee #{aggregations_dir}/non_cocoa_extensions.simple.txt`.split("\n")
simple_unique_extensions = `jq '' #{aggregations_dir}/non_cocoa_extensions.json | #{remove_double_quotes} | #{remove_first_comma} | sort | tee #{aggregations_dir}/unique_extensions.simple.txt`.split("\n")

# get the top 10 extended non-cocoa apis and aggregate how they're extended

api_names = simple_non_cocoa_extensions[0..9].map do |count_and_api| 
  /\s*\d*\s*(.*)/.match(count_and_api).captures.first # given a string with a number and one or more words etc, like "  227 Data and other stuff", extract "Data and other stuff"
  .gsub(':', 'conforms to') # convert colons because they can't be used in filenames
  .gsub(' ', '_')
end
chunked_api_aggregations = Hash.new
repo_sets.each_with_index do |repo_set, i|
  api_names.each do |api_name|
    observation_files = repo_set.join(' ')
    # repos with an extension of the supplied api
    extending_repos = `cat #{observation_files} | jq '. | select(.declarations.extension.parsed[].identifier=="#{api_name}") | .repository.full_name' | sort | uniq`.split("\n")

    # count function signatures grouped by uniq
    extending_functions = massage_counted_uniqued_results `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="#{api_name}") | .declarations | .function.parsed[].identifier' | sort | uniq -c | sort`
    
    if chunked_api_aggregations[api_name] == nil then
      chunked_api_aggregations[api_name] = {
        i => {
          'extending_repos' => extending_repos,
          'extending_functions' => extending_functions,
        }
      }
    else
      chunked_api_aggregations[api_name][i] = {
        'extending_repos' => extending_repos,
        'extending_functions' => extending_functions,
      }
    end
  end
end

# combine the chunked aggregations

all_api_aggregations = Hash.new
api_aggregations_dir = "#{aggregations_dir}/api"
`mkdir -p #{api_aggregations_dir}`
api_names.each do |api_name|
  all_extending_repos = Set.new
  all_extending_functions = Hash.new
  all_aggregations = chunked_api_aggregations[api_name].each do |repo_set_i, aggregations|
    aggregations['extending_repos'].each {|extending_repo| all_extending_repos << extending_repo }
    all_extending_functions.merge!(aggregations['extending_functions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
  end
  
  # write to files

  File.open("#{api_aggregations_dir}/#{api_name}.json", 'w') do |file|
    file << JSON.dump({
      'extending_repos' => all_extending_repos.to_a,
      'extending_functions' => all_extending_functions,
    })
  end

  # write consolidated, simple text versions of the results

  simple_extending_functions = `jq '.extending_functions' #{aggregations_dir}/api/#{api_name}.json | awk -F'":' '{print $2 $1};' | sort -rn | #{remove_double_quotes} | #{remove_first_comma} | tee #{aggregations_dir}/api/#{api_name}_functions.simple.txt`.split("\n")
end

# repo_sets.each_with_index do |repo_set, i|
#   api_names.each do |api_name|
#
#     # looking at common tasks, e.g. trimming
#
#     # count signatures containing a keyword by uniq
#     `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' | sort | uniq -c | sort | grep -i trim`
#
#     # whittling away by keyword (e.g., all the functions _except_ trim/substring functions)
#     `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' | grep -vi -e trim -e substring | sort | uniq -c | sort`
#
#     # sum counts of grouped signatures
#     `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' | sort | uniq -c | sort | grep -i trim | awk -F ' ' '{sum+=$0} END {print sum}'`
#
#     # search for implementations of a particular function signature
#     `ag --swift --after=10 --literal "trim() -> String" 2>/dev/null`
#
#     # grab the return statements from the 10 lines following each text match of the signature, sort, count by uniq
#     `ag --nofilename --swift --after=3 --literal "trim() -> String" 2>/dev/null | grep return | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sort | uniq -c | sort`
#
#   end
# end
