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
  
  # split whole list into individual lines, each containing one extension with its frequency count
  result_string.split("\n").each do |extension_count|     
    # split that one item into the count string and the api name string, and trim whitespace from the count string and api name string
    trimmed_components = extension_count.split("\"").map {|extension_count_component| extension_count_component.strip }

    result_hash[trimmed_components[1]] = trimmed_components[0]
  end
  
  result_hash
end

# given a string with a number and one or more words etc, like "  227 Data and other stuff", extract "Data and other stuff"
def strip_frequency_count line
  /\s*\d*\s*(.*)/.match(line).captures.first 
end

def hash_values_to_i hash
  temp = Hash.new
  hash.each do |decl, count|
    temp[decl] = count.to_i
  end
  temp
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
  
  aggregations_hash[i] = {
    'extensions' => extensions,
    'non_cocoa_extensions' => non_cocoa_extensions,
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

aggregations_hash.each do |repo_set_i, aggregations|
  all_extensions.merge!(aggregations['extensions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
  all_extensions = hash_values_to_i all_extensions
  all_non_cocoa_extensions.merge!(aggregations['non_cocoa_extensions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
  all_non_cocoa_extensions = hash_values_to_i all_non_cocoa_extensions
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

total_extension_declarations = 0
total_non_cocoa_extension_declarations = 0
all_extensions.each do |extension, count|
  total_extension_declarations += count
end
all_non_cocoa_extensions.each do |extension, count|
  total_non_cocoa_extension_declarations += count
end

File.open("#{aggregations_dir}/_stats.json", 'w') do |file|
  file << JSON.dump({
    'unique_extension_declarations' => all_extensions.size,
    'non_cocoa_unique_extension_declarations' => all_non_cocoa_extensions.size,
    'total_extension_declarations' => total_extension_declarations,
    'total_non_cocoa_extension_declarations' => total_non_cocoa_extension_declarations,
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
  strip_frequency_count(count_and_api)
  .gsub(':', 'conforms to') # convert colons because they can't be used in filenames
  .gsub(' ', '_')
end
chunked_api_aggregations = Hash.new
repo_sets.each_with_index do |repo_set, i|
  api_names.each do |api_name|
    observation_files = repo_set.join(' ')
    # repos with an extension of the supplied api
    extending_repos = massage_counted_uniqued_results `cat #{observation_files} | jq '. | select(.declarations.extension.parsed[].identifier=="#{api_name}") | .repository.full_name' | sort | uniq -c | sort`

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

simple_extending_functions_by_api = Hash.new
api_aggregations_dir = "#{aggregations_dir}/api"
`mkdir -p #{api_aggregations_dir}`
api_names.each do |api_name|
  all_extending_repos = Hash.new
  all_extending_functions = Hash.new
  all_aggregations = chunked_api_aggregations[api_name].each do |repo_set_i, aggregations|
    all_extending_functions.merge!(aggregations['extending_functions']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
    all_extending_repos.merge!(aggregations['extending_repos']) {|key, a_val, b_val| a_val.to_i + b_val.to_i }
    all_extending_repos = hash_values_to_i all_extending_repos
    all_extending_functions = hash_values_to_i all_extending_functions
  end
  
  total_extending_functions = 0
  all_extending_functions.each do |extension, count|
    total_extending_functions += count
  end
  
  # write to files

  File.open("#{api_aggregations_dir}/#{api_name}.json", 'w') do |file|
    file << JSON.dump({
      'extending_repos' => all_extending_repos,
      'extending_functions' => all_extending_functions,
      'unique_extending_repos' => all_extending_repos.size,
      'unique_extending_functions' => all_extending_functions.size,
      'total_extending_functions' => total_extending_functions,
    })
  end

  # write consolidated, simple text versions of the results

  simple_extending_functions = `jq '.extending_functions' #{aggregations_dir}/api/#{api_name}.json | awk -F'":' '{print $2 $1};' | sort -rn | #{remove_double_quotes} | #{remove_first_comma} | tee #{aggregations_dir}/api/#{api_name}_functions.simple.txt`.split("\n")
  
  # memoize the function lists for next step
  simple_extending_functions_by_api[api_name] = simple_extending_functions
end

# get the top 10 extending function names for each api (so, just the part to the left of the first opening parens or generic expression, if present)
top_extending_functions_by_api = Hash.new
simple_extending_functions_by_api.each do |api_name, simple_extending_functions|
  top_extending_functions_by_api[api_name] = simple_extending_functions[0..9].map do |x| 
    signature = strip_frequency_count(x)
    first_generic_opening_bracket = signature '<'
    first_opening_parenthesis = signature '('
    if first_generic_opening_bracket < first_opening_parenthesis then
      signature[0..first_generic_opening_bracket]
    else
      signature[0..first_opening_parenthesis]
    end
  end
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
