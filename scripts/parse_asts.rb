require 'json'

asts_dir = 'asts'
`mkdir -p #{asts_dir}`

all_repositories = Dir.entries('repositories')

all_repositories.each do |repository|
  next if repository == '.' || repository == '..' || repository == '.DS_Store'
  
  output_file = "#{asts_dir}/#{repository}.ast"
  
  puts "parsing #{repository}"

  repo_dir = "repositories/#{repository}"
    
  swift_file_paths = `find #{repo_dir} -type f -name '*.swift'`.split("\n")
  
  parse_output = swift_file_paths.inject(Array.new) do |all_output_lines, swift_file_path|
    all_output_lines += `swiftc -print-ast '#{swift_file_path}' 2>/dev/null`.split("\n")
  end
  
  File.open(output_file, 'w') do |file|
    file << JSON.dump(parse_output)
  end
end
