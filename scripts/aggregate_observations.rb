require 'json'
require 'set'
require_relative '_helpers'

# do the aggregating on each chunk

aggregations_hash = Hash.new
chunked_repo_sets.each_with_index do |repo_set, i|
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

# count totals

total_extension_declarations = 0
total_non_cocoa_extension_declarations = 0
all_extensions.each do |extension, count|
  total_extension_declarations += count
end
all_non_cocoa_extensions.each do |extension, count|
  total_non_cocoa_extension_declarations += count
end

# write to file

`mkdir -p #{AGGREGATIONS_DIR}`
File.open("#{AGGREGATIONS_DIR}/_all.json", 'w') do |file|
  file << JSON.dump({
    'all_extensions' => {
      'declarations' => all_extensions,
      'unique_declaration_count' => all_extensions.size,
      'total_declaration_count' => total_extension_declarations,
    },
    'non_cocoa_extensions' => {
      'declarations' => all_non_cocoa_extensions,
      'unique_declaration_count' => all_non_cocoa_extensions.size,
      'total_declaration_count' => total_non_cocoa_extension_declarations,
    }
  })
end

# write consolidated, simple text versions of the all_[non_cocoa]extensions lists

{ 'extensions' => all_extensions, 'non_cocoa_extensions' => all_non_cocoa_extensions }.each do |filename, hash|
  simple_filename = "#{AGGREGATIONS_DIR}/#{filename}.simple.txt"
  `rm #{simple_filename}`
  File.open("#{simple_filename}", 'a') do |file|
    hash.keys.sort do |a, b|
      hash[b] - hash[a] # descending sort
    end.each do |extension_declaration|
      file << "#{hash[extension_declaration]} #{extension_declaration}\n"
    end
  end
end
