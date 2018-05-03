require 'json'

def massage_results input
  input.split("\n").delete_if{|x|x.empty?}.map{|x|x.strip}
end

def massage_multiline_comment_result input
  input.split('*/').map{|x|x+"*/"}
end

def parsed_declarations abstract_syntax_tree, declaration_type
  declarations = abstract_syntax_tree.select do |line|
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

def test_extension_end line, scopes
  false
end

def extract_extensions abstract_syntax_tree
  extensions = Array.new

  extension_decl = 'extension'
  
  0.upto(abstract_syntax_tree.count - 1) do |i|
    raw_line = abstract_syntax_tree[i]

    abstract_syntax_tree_line = raw_line.strip
    if abstract_syntax_tree_line.include?(extension_decl + ' ') then
      extension_hash = extract_modifiers abstract_syntax_tree_line, extension_decl
      
      # search to the end of the extension. it can have nested braced scopes, so maintain a count to find the true end of the extension
      extension_body = Array.new
      scopes = 0
      found_extension_end = false
      i.upto(abstract_syntax_tree.count - 1) do |j|
        next_line = abstract_syntax_tree[j]

        # reduce the line to just curly braces
        braces_string = next_line.gsub(/[^\{\}]?/,'')

        # eliminate pairs, like for lines like `var something: Any { get }`
        until braces_string == braces_string.gsub('{}', '') do
          braces_string.gsub!('{}', '')
        end
  
        braces_string.chars.each do |brace|
          if brace == '{' then
            scopes += 1
          elsif brace == '}' then
            if scopes == 0 then
              # end of extension!
              found_extension_end = true
              break
            else
              scopes -= 1
              if scopes == 0 then
                # end of extension!
                found_extension_end = true
                break
              end
            end
          else
            puts "unexpected character left over in braces string: #{braces_string}"
          end
        end
        
        break if found_extension_end
        
        # if we're still in the extension body, accumulate lines
        extension_body << next_line
      end
      
      extension_hash['declarations'] = extract_declarations(extension_body, false, false)
      extensions << extension_hash
    end
  end
  
  extensions
end

def extract_declarations abstract_syntax_tree, include_raw_search, include_extensions
  declarations = Hash.new
  
  declarations["function"] = { 'parsed' => parsed_declarations(abstract_syntax_tree, 'func') }
  if include_raw_search then
    declarations["function"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`)
  end
  
  declarations["enum"] = { 'parsed' => parsed_declarations(abstract_syntax_tree, 'enum') }
  if include_raw_search then
    declarations["enum"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup enum`)
  end
  
  declarations["protocol"] = { 'parsed' => parsed_declarations(abstract_syntax_tree, 'protocol') }
  if include_raw_search then
    declarations["protocol"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup protocol`)
  end
  
  declarations["struct"] = { 'parsed' => parsed_declarations(abstract_syntax_tree, 'struct') }
  if include_raw_search then
    declarations["struct"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup struct`)
  end
  
  declarations["class"] = { 'parsed' => parsed_declarations(abstract_syntax_tree, 'class') }
  if include_raw_search then
    declarations["class"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup class`)
  end
  
  declarations["typealias"] = { 'parsed' => parsed_declarations(abstract_syntax_tree, 'typealias') }
  if include_raw_search then
    declarations["typealias"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup typealias`)
  end
  
  declarations["operator"] = { 'parsed' => parsed_declarations(abstract_syntax_tree, 'operator') }
  if include_raw_search then
    declarations["operator"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup operator`)
  end
  
  if include_extensions then
    declarations["extension"] = { 'parsed' => extract_extensions(abstract_syntax_tree) }
    if include_raw_search then
      declarations["extension"]['raw'] = massage_results(`ag -swQ --swift --nofilename --nogroup extension`)
    end
  end
  
  declarations
end

def extract_comments abstract_syntax_tree
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

def extract_readmes repo_info, abstract_syntax_tree
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
    
  abstract_syntax_tree = Array.new
  File.open("asts/#{repository}.ast", 'r') do |file|
    abstract_syntax_tree = JSON.parse(file.read)
  end

  repo_dir = "repositories/#{repository}"
  Dir.chdir(repo_dir) do
    
    swift_file_paths = `find . -type f -name '*.swift'`.split("\n")

    declarations = extract_declarations abstract_syntax_tree, true, true
    comments = extract_comments abstract_syntax_tree
    extract_readmes repo_info, abstract_syntax_tree
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
