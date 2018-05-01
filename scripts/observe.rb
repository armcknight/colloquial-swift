require 'json'

def massage_results input
  input.split("\n").delete_if{|x|x.empty?}.map{|x|x.strip}
end

def massage_multiline_comment_result input
  input.split('*/').map{|x|x+"*/"}
end

observations_metadata_dir = 'observations'
`mkdir -p #{observations_metadata_dir}`

all_repositories = Array.new
File.open('filtering/repos_with_podspecs.json', 'r') do |file|
  all_repositories = JSON.parse(file.read)
end

all_repositories.each do |repository|
  next if repository == '.' || repository == '..' || repository == '.DS_Store'
  
  declarations = Hash.new
  comments = Hash.new
  lines_of_code_counts = Hash.new
  repo_dir = "repositories/#{repository}"
  Dir.chdir(repo_dir) do
    declarations["function"] = massage_results `ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`
    declarations["enum"] = massage_results `ag -swQ --swift --nofilename --nogroup enum`
    declarations["extension"] = massage_results `ag -swQ --swift --nofilename --nogroup extension`
    declarations["protocol"] = massage_results `ag -swQ --swift --nofilename --nogroup protocol`
    declarations["struct"] = massage_results `ag -swQ --swift --nofilename --nogroup struct`
    declarations["class"] = massage_results `ag -swQ --swift --nofilename --nogroup class`
    declarations["typealias"] = massage_results `ag -swQ --swift --nofilename --nogroup typealias`
    declarations["operator"] = massage_results `ag -swQ --swift --nofilename --nogroup operator`
    
    # find comments starting with //
    comments['inline'] = massage_results `ag --swift --nofilename --nogroup --nomultiline "^(//)[^/]+"`
    
    # find comments starting with ///
    comments['swift_inline_doc'] = massage_results `ag --swift --nofilename --nogroup "^(///)"`
    
    # the next two regular expressions were adapted from https://stackoverflow.com/a/36328890/4789448
    
    # find /* */ comments
    comments['multine'] = massage_multiline_comment_result `ag --swift --nofilename --nogroup "/\\*[^*]+\\*+(?:[^/*][^*]*\\*+)*/"`
    
    # find /** */ documentation comments
    comments['headerdoc'] = massage_multiline_comment_result `ag --swift --nofilename --nogroup "/\\*\\*[^*]+\\*+(?:[^/*][^*]*\\*+)*/"`
    
    # count total lines of code per swift file
    swift_file_paths = `find . -type f -name "*.swift"`.split("\n")
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
  end
  
  metadata_file = "#{observations_metadata_dir}/#{repository}.json"
  final_hash = {
      'repository' => repository,
      'declarations' => declarations,
      'comments' => comments,
      'lines_of_code_counts' => lines_of_code_counts
  }
  File.open(metadata_file, 'w') do |file|
    file << JSON.dump(final_hash)
  end
end
