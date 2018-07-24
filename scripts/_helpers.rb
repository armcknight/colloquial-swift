# locations

AGGREGATIONS_DIR = 'aggregations'
OBSERVATIONS_DIR = 'observations'

# controls (set to -1 for all instead of top N)

TOP_EXTENDED_API_AMOUNT = 10
TOP_EXTENDING_FUNCTION_AMOUNT = 10
TOP_EXTENDING_FUNCTION_NAME_KEYWORD_AMOUNT = 10

# unix stream processing pipeline commands

REMOVE_FIRST_COMMA = 'sed s/,//1'
REMOVE_DOUBLE_QUOTES = "sed s/\\\"//g"
REVERSE_COLUMNS = 'awk -F\'":\' \'{print $2 $1};\''
REMOVE_ENCLOSING_BRACES = 'sed \'1d;$d\''

# remove superfluous words that don't convey intent of functions
SUPERFLUOUS_WORDS = [ 
  # common two-letter words
  'an', 'as', 'at', 'it', 'to', 'in', 'is', 'on', 'am', 'be', 'no', 'do', 'of', 'go', 'if', 'so', 'by', 'or',
  
  # common three-letter words
  'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'any', 'can', 'was', 'our', 'get', 'has', 'how', 'did', 'its', 'let', 'put', 'too', 'use',
  
  # prepositions
  'with', 'from', 'into', 'during', 'including', 'until', 'among', 'about', 
]

# functions

# split on uppercase, preserving acronyms, from https://stackoverflow.com/a/48019684/4789448
def tokenize_camel_case_string string
  string.gsub(/([[:lower:]\\d])([[:upper:]])/, '\1 \2')
        .gsub(/([^-\\d])(\\d[-\\d]*( |$))/,'\1 \2')
        .gsub(/([[:upper:]])([[:upper:]][[:lower:]\\d])/, '\1 \2')
        .split 
end

def extract_function_name signature
  first_generic_opening_bracket = signature.index '<'
  first_opening_parenthesis = signature.index '('
  last_closing_parenthesis = signature.size - signature.reverse.index(')') - 1
  
  if first_generic_opening_bracket == nil || first_generic_opening_bracket > first_opening_parenthesis then
    signature[0...first_opening_parenthesis].strip
  else
    signature[0...first_generic_opening_bracket].strip
  end
end

def strip_return_clause signature
  clause_separator = '->'
  if signature.include? clause_separator then
    clause_start_i = signature.index clause_separator
    signature[0...clause_start_i].strip
  else
    signature
  end
end

def slugified_api_name api_name
  api_name
  .gsub(':', 'conforms to') # convert colons because they can't be used in filenames
  .gsub(' ', '_')
end

# chunk up the set of repos to process so `jq` doesn't run out of memory
def chunked_repo_sets 
  all_repositories = Dir.entries(OBSERVATIONS_DIR).select{|x| x != '.' && x != '..' && x != '.DS_Store'}.map{|x| "#{OBSERVATIONS_DIR}/" + x}
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
  repo_sets
end

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
