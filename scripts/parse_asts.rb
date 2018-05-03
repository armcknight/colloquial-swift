require 'json'

asts_dir = 'asts'
`mkdir -p #{asts_dir}`

all_repositories = Array.new
File.open('filtering/repos_with_podspecs.json', 'r') do |file|
  all_repositories = JSON.parse(file.read)
end

all_repositories.each do |repository|
  next if repository == '.' || repository == '..' || repository == '.DS_Store'
  
  puts "parsing #{repository}"

  repo_dir = "repositories/#{repository}"
    
  swift_file_paths = `find #{repo_dir} -type f -name '*.swift'`.split("\n")
  
  parse_output = swift_file_paths.inject(Array.new) do |all_output_lines, swift_file_path|
    all_output_lines += `swiftc -print-ast '#{swift_file_path}' 2>/dev/null`.split("\n")
  end
  
  File.open("#{asts_dir}/#{repository}.ast", 'w') do |file|
    file << JSON.dump(parse_output)
  end
end
