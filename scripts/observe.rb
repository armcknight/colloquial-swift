require 'json'

def massage_results input
  input.split("\n").delete_if{|x|x.empty?}.map{|x|x.strip}
end

def massage_multiline_comment_result input
  input.split('*/').map{|x|x+"*/"}
end

def parsed_declarations parse_output, declaration_type
  declarations = parse_output.select do |line|
    if declaration_type == 'class' then
      line.include?(declaration_type + ' ') and !line.include?('func ')
    else
      line.include?(declaration_type + ' ')
    end
  end
  massaged_declarations = declarations.map do |decl| decl.strip end
  massaged_declarations.map do |declaration|
    extract_modifiers declaration, declaration_type
  end
end

def extract_modifiers declaration, declaration_type
  parts = declaration.split(declaration_type + ' ')
  { 
    'identifier' => parts[1..-1].join.gsub(' {', '').strip, 
    'modifiers' => parts.first.split(' ').map{ |x| x.strip } 
  }
end

def extract_github_metadata github_results, repository
  github_metadata = github_results.select{|x| x['full_name'].gsub('/', '_') == repository}.first
  if github_metadata == nil then
    { 'full_name' => repository }
  else
    github_metadata
  end
end

def test_extension_end line
  # reduce the line to just curly braces
  braces_string = line.gsub(/[^\{\}]?/,'')
  
  # eliminate pairs, like for lines like `var something: Any { get }`
  until braces_string == braces_string.gsub('{}', '') do
    braces_string.gsub!('{}', '')
  end
  
  braces_string.each do |brace|
    if brace == '{' then
      scopes += 1
    elsif brace == '}' then
      if scopes == 0 then
        # end of extension!
        return true
      else
        scopes -= 1
      end
    else
      puts "unexpected character left over in braces string: #{braces_string}"
    end
  end
  false
end

def extract_extensions parse_output
  extensions = Array.new
  
  extension_decl = 'extension'
  0..parse_output.count do |i|
    parse_output_line = parse_output[i].strip
    if parse_output_line.include?(extension_decl + ' ') then
      extension_hash = extract_modifiers parse_output_line, extension_decl
      
      # search to the end of the extension. it can have nested braced scopes, so maintain a stack to find the true end of the extension
      extension_body = Array.new
      scopes = 0
      found_extension_end = false
      i..parse_output.count do |j|
        next_line = parse_output[j]
        break if test_extension_end next_line
        extension_body << next_line
      end
      
      
    end
  end
  
  extensions
end

def extract_declarations parse_output, include_raw_search, include_extensions
  declarations = Hash.new
  
  declarations["function"] = {
    'parsed' => parsed_declarations(parse_output, 'func')
  }
  if include_raw_search then
    declarations["function"]['raw'] => massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["enum"] = {
    'raw' => massage_results(`ag -swQ --swift --nofilename --nogroup enum`),
    'parsed' => parsed_declarations(parse_output, 'enum')
  }
  if include_raw_search then
    declarations["function"]['raw'] => massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["protocol"] = {
    'raw' => massage_results(`ag -swQ --swift --nofilename --nogroup protocol`),
    'parsed' => parsed_declarations(parse_output, 'protocol')
  }
  if include_raw_search then
    declarations["function"]['raw'] => massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["struct"] = {
    'raw' => massage_results(`ag -swQ --swift --nofilename --nogroup struct`),
    'parsed' => parsed_declarations(parse_output, 'struct')
  }
  if include_raw_search then
    declarations["function"]['raw'] => massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["class"] = {
    'raw' => massage_results(`ag -swQ --swift --nofilename --nogroup class`),
    'parsed' => parsed_declarations(parse_output, 'class')
  }
  if include_raw_search then
    declarations["function"]['raw'] => massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["typealias"] = {
    'raw' => massage_results(`ag -swQ --swift --nofilename --nogroup typealias`),
    'parsed' => parsed_declarations(parse_output, 'typealias')
  }
  if include_raw_search then
    declarations["function"]['raw'] => massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["operator"] = {
    'raw' => massage_results(`ag -swQ --swift --nofilename --nogroup operator`),
    'parsed' => parsed_declarations(parse_output, 'operator')
  }
  if include_raw_search then
    declarations["function"]['raw'] => massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["extension"] = {
    'raw' => massage_results( )`ag -swQ --swift --nofilename --nogroup extension`),
    'parsed' => extract_extensions(parse_output)
  
  declarations
end

def extract_comments parse_output
  comments = Hash.new
  
  # find comments starting with //
  comments['inline'] = massage_results `ag --swift --nofilename --nogroup --nomultiline "^(//)[^/]+"`
  
  # find comments starting with ///
  comments['swift_inline_doc'] = massage_results `ag --swift --nofilename --nogroup "^(///)"`
  
  # the next two regular expressions were adapted from https://stackoverflow.com/a/36328890/4789448
  
  # find /* */ comments
  comments['multine'] = massage_multiline_comment_result `ag --swift --nofilename --nogroup "/\\*[^*]+\\*+(?:[^/*][^*]*\\*+)*/"`
  
  # find /** */ documentation comments
  comments['headerdoc'] = massage_multiline_comment_result `ag --swift --nofilename --nogroup "/\\*\\*[^*]+\\*+(?:[^/*][^*]*\\*+)*/"`
  
  comments
end

def extract_readmes repo_info, parse_output
  readme_paths = `find . -type f -iname 'readme*'`.split("\n")
  readme_paths.each do |readme_path|
    File.open(readme_path, 'r') do |file|
      if repo_info['readmes'] == nil then
        repo_info['readmes'] = { 'path' => readme_path, 'content' => file.read}
      else
        repo_info['readmes']['path'] = file.read
      end
    end
  end
end

def count_lines_of_code swift_file_paths
  lines_of_code_counts = Hash.new
  
  unless swift_file_paths.empty? then
    current_repo_lines_of_code_counts = Hash.new
    swift_file_paths.each do |swift_file_path|
      swift_filename = swift_file_path.split('/')[-1]
      File.open(swift_file_path, 'r') do |file|
      current_repo_lines_of_code_counts[swift_filename] = file.readlines.count
      end
    end
    lines_of_code_counts['totals'] = current_repo_lines_of_code_counts

    total_lines_of_code = current_repo_lines_of_code_counts.values.reduce(:+)
    lines_of_code_counts['average'] = total_lines_of_code / current_repo_lines_of_code_counts.values.count
    lines_of_code_counts['min'] = current_repo_lines_of_code_counts.values.min
    lines_of_code_counts['max'] = current_repo_lines_of_code_counts.values.max
  end
  
  lines_of_code_counts
end

observations_metadata_dir = 'observations'
`mkdir -p #{observations_metadata_dir}`

all_repositories = Array.new
File.open('filtering/repos_with_podspecs.json', 'r') do |file|
  all_repositories = JSON.parse(file.read)
end

# get repo metadata from combined github search result json
github_results = Array.new
File.open("github_search_results/_all_results.json", 'r') do |file|
  github_results = JSON.parse(file.read)
end

all_repositories.each do |repository|
  next if repository == '.' || repository == '..' || repository == '.DS_Store'
  
  puts "analyzing #{repository}"
  
  declarations = Hash.new
  comments = Hash.new
  lines_of_code_counts = Hash.new
  repo_info = extract_github_metadata github_results, repository

  repo_dir = "repositories/#{repository}"
  Dir.chdir(repo_dir) do
    
    swift_file_paths = `find . -type f -name '*.swift'`.split("\n")
    
    parse_output = swift_file_paths.inject(Array.new) do |all_output_lines, swift_file_path|
      all_output_lines += `swiftc -print-ast '#{swift_file_path}' 2>/dev/null`.split("\n")
    end
    
    repo_info['ast'] = parse_output

    declarations = extract_declarations parse_output
    comments = extract_comments parse_output
    extract_readmes repo_info, parse_output
    lines_of_code_counts = count_lines_of_code swift_file_paths
  end
  
  metadata_file = "#{observations_metadata_dir}/#{repository}.json"
  final_hash = {
      'repository' => repo_info,
      'declarations' => declarations,
      'comments' => comments,
      'lines_of_code_counts' => lines_of_code_counts
  }
  File.open(metadata_file, 'w') do |file|
    file << JSON.dump(final_hash)
  end
end
