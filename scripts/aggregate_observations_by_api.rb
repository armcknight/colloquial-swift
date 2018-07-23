require 'json'
require_relative '_helpers'

repo_sets = chunked_repo_sets
all_api_aggregations = Hash.new

# get simple lists back out

simple_extensions = `cat #{AGGREGATIONS_DIR}/extensions.simple.txt`.split("\n")
simple_non_cocoa_extensions = `cat #{AGGREGATIONS_DIR}/non_cocoa_extensions.simple.txt`.split("\n")

# get the top 10 extended non-cocoa apis and aggregate how they're extended

api_names = simple_non_cocoa_extensions[0...TOP_EXTENDED_API_AMOUNT].map {|count_and_api| strip_frequency_count(count_and_api)}

chunked_api_aggregations = Hash.new
repo_sets.each_with_index do |repo_set, i|
  api_names.each do |api_name|
    observation_files = repo_set.join(' ')
    # repos with an extension of the supplied api
    extending_repos = massage_counted_uniqued_results `cat #{observation_files} | jq '. | select(.declarations.extension.parsed[].identifier=="#{api_name}") | .repository.full_name' | sort | uniq -c | sort`

    # count function signatures grouped by uniq
    extending_functions = massage_counted_uniqued_results `cat #{observation_files} | jq '.declarations.extension.parsed[] | select(.identifier=="#{api_name}") | .declarations | .function.parsed[].identifier' | sort | uniq -c | sort`
    
    repos_and_functions_hash = {
      'extending_repos' => extending_repos,
      'extending_functions' => extending_functions,
    }
    
    if chunked_api_aggregations[api_name] == nil then
      chunked_api_aggregations[api_name] = {i => repos_and_functions_hash}
    else
      chunked_api_aggregations[api_name][i] = repos_and_functions_hash
    end
  end
end

# combine the chunked aggregations

simple_extending_function_names_by_api = Hash.new
`mkdir -p #{API_AGGREGATIONS_DIR}`
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
  
  # add data points to big aggregation hash

  all_api_aggregations[api_name] ={
    'extending_repos' => all_extending_repos,
    'extending_repo_count' => all_extending_repos.size,
    'extending_functions' => all_extending_functions,
    'unique_extending_function_count' => all_extending_functions.size,
    'total_extending_function_count' => total_extending_functions,
  }

  # collect simple text version of extensing functions with counts, write to file 
  
  simple_filename = "#{AGGREGATIONS_DIR}/api/#{slugified_api_name api_name}.functions.simple.txt"
  `rm -f #{simple_filename}`
  simple_extending_functions = Array.new
  File.open("#{simple_filename}", 'a') do |file|
    all_extending_functions.keys.sort do |a, b|
      all_extending_functions[b] - all_extending_functions[a] # descending sort
    end.each do |function_declaration|
      function_with_count = "#{all_extending_functions[function_declaration]} #{function_declaration}"
      file << "#{function_with_count}\n"
      simple_extending_functions << function_with_count
    end
  end
  
  # memoize the function lists for next step
  simple_extending_function_names_by_api[api_name] = simple_extending_functions
end

# get the extending function names (just the part to the left of the first opening parens, or generic expression if present) for each api mapped to their full signatures

top_extending_function_signatures_to_names_by_api = Hash.new
simple_extending_function_names_by_api.each do |api_name, simple_extending_functions|
  simple_extending_functions.each do |signature_with_count| 
    signature = strip_frequency_count signature_with_count
    function_name = extract_function_name signature
    
    if top_extending_function_signatures_to_names_by_api[api_name] == nil then
      top_extending_function_signatures_to_names_by_api[api_name] = {signature => function_name}
    else 
      top_extending_function_signatures_to_names_by_api[api_name][signature] = function_name
    end
  end
end

# tokenize the function names into keyword lists per API

extending_function_keywords_by_api = Hash.new
top_extending_function_signatures_to_names_by_api.each do |api_name, top_extending_function_signatures_to_names|
  top_extending_function_signatures_to_names.each do |function_signature, function_name|
    keywords = function_name.split('_').reduce(Array.new) do |keyword_list, next_function_name_token|
      tokenized_by_case = tokenize_camel_case_string next_function_name_token
      keyword_list.concat tokenized_by_case
    end
    
    if extending_function_keywords_by_api[api_name] == nil then
      extending_function_keywords_by_api[api_name] = keywords
    else
      extending_function_keywords_by_api[api_name].concat keywords
    end
  end
  
  # distill to unique keywords with frequencies
  
  keywords_with_frequencies = Hash.new
  extending_function_keywords_by_api[api_name].uniq.each do |unique_keyword|
    count = extending_function_keywords_by_api[api_name].select {|x| x == unique_keyword}.size
    keywords_with_frequencies[unique_keyword] = count
  end
  
  # write to simple text file
  
  simple_filename = "#{AGGREGATIONS_DIR}/api/#{slugified_api_name api_name}.keywords.simple.txt"
  `rm -f #{simple_filename}`
  File.open("#{simple_filename}", 'a') do |file|
    keywords_with_frequencies.keys.sort do |a, b|
      keywords_with_frequencies[b] - keywords_with_frequencies[a] # descending sort
    end.each do |keyword|
      file << "#{keywords_with_frequencies[keyword]} #{keyword}\n"
    end
  end
  hash_values_to_i keywords_with_frequencies
  
  total_keyword_count = 0
  keywords_with_frequencies.each do |keyword, count|
    total_keyword_count += count  
  end
  
  # put in big hash to write to file later
  all_api_aggregations[api_name]['total_extending_keyword_count'] = total_keyword_count
  all_api_aggregations[api_name]['unique_extending_keyword_count'] = keywords_with_frequencies.size
  all_api_aggregations[api_name]['extending_keywords'] = keywords_with_frequencies
end
  
# index all functions (not just top N) by keyword for current api into new Hash

function_families_by_api = Hash.new
top_extending_function_signatures_to_names_by_api.each do |api_name, top_extending_function_signatures_to_names|
  extending_function_keywords_by_api[api_name].uniq.each do |keyword|

    functions_including_keyword = Hash.new
    simple_extending_function_names_by_api[api_name].select do |function_signature|
      top_extending_function_signatures_to_names[strip_frequency_count(function_signature)].include? keyword
    end.each do |function_signature|
      stripped_signature = strip_frequency_count(function_signature)
      count = function_signature.gsub(stripped_signature, '').strip.to_i
      functions_including_keyword[function_signature] = count
    end

    if function_families_by_api[api_name] == nil then
      function_families_by_api[api_name] = {
        keyword => functions_including_keyword
      }
    else
      function_families_by_api[api_name][keyword] = functions_including_keyword
    end
  end

  all_api_aggregations[api_name]['function_families'] = function_families_by_api[api_name]
end

# write big hash to file

all_api_aggregations.keys.each do |api_name|
  File.open("#{API_AGGREGATIONS_DIR}/#{slugified_api_name api_name}.json", 'w') do |file|
    file << JSON.dump(all_api_aggregations[api_name])
  end
end

exit

# aggregate based on function keywords

repo_sets.each_with_index do |repo_set, i|
  api_names.each do |api_name|
    simple_extending_function_names_by_api[api_name].each do |function|

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