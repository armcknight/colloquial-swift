require 'json'
require_relative '_helpers'

repo_sets = chunked_repo_sets

# get simple lists back out

simple_extensions = `cat #{AGGREGATIONS_DIR}/extensions.simple.txt`.split("\n")
simple_non_cocoa_extensions = `cat #{AGGREGATIONS_DIR}/non_cocoa_extensions.simple.txt`.split("\n")

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
api_AGGREGATIONS_DIR = "#{AGGREGATIONS_DIR}/api"
`mkdir -p #{api_AGGREGATIONS_DIR}`
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

  File.open("#{api_AGGREGATIONS_DIR}/#{api_name}.json", 'w') do |file|
    file << JSON.dump({
      'extending_repos' => all_extending_repos,
      'extending_functions' => all_extending_functions,
      'unique_extending_repos' => all_extending_repos.size,
      'unique_extending_functions' => all_extending_functions.size,
      'total_extending_functions' => total_extending_functions,
    })
  end

  # write consolidated, simple text versions of the results

  simple_extending_functions = `jq '.extending_functions' #{AGGREGATIONS_DIR}/api/#{api_name}.json | #{REMOVE_ENCLOSING_BRACES} | #{REVERSE_COLUMNS} | sort -rn | #{REMOVE_DOUBLE_QUOTES} | #{REMOVE_FIRST_COMMA} | tee #{AGGREGATIONS_DIR}/api/#{api_name}_functions.simple.txt`.split("\n")
  
  # memoize the function lists for next step
  simple_extending_functions_by_api[api_name] = simple_extending_functions
end

# get the top 10 extending function names for each api (so, just the part to the left of the first opening parens or generic expression, if present)

top_extending_functions_by_api = Hash.new
simple_extending_functions_by_api.each do |api_name, simple_extending_functions|
  top_extending_functions_by_api[api_name] = simple_extending_functions[0..9].map do |x| 
    signature = strip_frequency_count(x)
    first_generic_opening_bracket = signature.index '<'
    first_opening_parenthesis = signature.index '('
    last_closing_parenthesis = signature.size - signature.reverse.index(')') - 1
    puts "signature #{signature}; last_closing_parenthesis: #{last_closing_parenthesis}"
    if first_generic_opening_bracket == nil || first_generic_opening_bracket > first_opening_parenthesis then
      signature[0...first_opening_parenthesis]
    else
      signature[0...first_generic_opening_bracket]
    end
  end
end

# tokenize the function names into keyword lists per API  

extending_function_keywords_by_api = Hash.new
top_extending_functions_by_api.each do |api_name, top_extending_functions|
  top_extending_functions.each do |function_name|
    tokenized = function_name.split('_').reduce(Array.new) do |acc, next_obj|
      tokenized_by_case = next_obj.gsub(/([[:lower:]\\d])([[:upper:]])/, '\1 \2') \
        .gsub(/([^-\\d])(\\d[-\\d]*( |$))/,'\1 \2') \
        .gsub(/([[:upper:]])([[:upper:]][[:lower:]\\d])/, '\1 \2') \
        .split # splitting on uppercase, preserving acronyms, from https://stackoverflow.com/a/48019684/4789448
      acc.concat tokenized_by_case
    end
    
    if extending_function_keywords_by_api[api_name] == nil then
      extending_function_keywords_by_api[api_name] = tokenized
    else
      extending_function_keywords_by_api[api_name].concat tokenized
    end
  end
end

puts extending_function_keywords_by_api
exit


# aggregate based on function keywords

repo_sets.each_with_index do |repo_set, i|
  api_names.each do |api_name|
    simple_extending_functions_by_api[api_name].each do |function|

      # looking at common tasks, e.g. trimming

      # count signatures containing a keyword by uniq
      `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' | sort | uniq -c | sort | grep -i trim`

      # whittling away by keyword (e.g., all the functions _except_ trim/substring functions)
      `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' | grep -vi -e trim -e substring | sort | uniq -c | sort`

      # sum counts of grouped signatures
      `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' | sort | uniq -c | sort | grep -i trim | awk -F ' ' '{sum+=$0} END {print sum}'`

      # search for implementations of a particular function signature
      `ag --swift --after=10 --literal "trim() -> String" 2>/dev/null`

      # grab the return statements from the 10 lines following each text match of the signature, sort, count by uniq
      `ag --nofilename --swift --after=3 --literal "trim() -> String" 2>/dev/null | grep return | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sort | uniq -c | sort`
    end
  end
end
