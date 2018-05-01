require 'fileutils'
require 'json'

reverse_removal = ARGV[0] == 'reverse'

filter_results_dir = 'filtering'
`mkdir #{filter_results_dir}`

repositories_dir = 'repositories'
removed = Hash.new
Dir.entries(repositories_dir).each do |repository|
  next if repository == '.' || repository == '..' || repository == '.DS_Store'
  
  Dir.chdir("#{repositories_dir}/#{repository}") do
    if reverse_removal then
      `git checkout .`
      next
    else
      ['Pods', 'Carthage', '*Example*', '*Test*', '*Demo*'].each do |dependency_type|
        dependency_directories = `find . -type d -name "#{dependency_type}"`
        dependency_directories.split("\n").each do |dependency_directory|
          repo_dependency_directory = "#{repository}/#{dependency_directory}"
          FileUtils.rm_rf(dependency_directory)
          if removed[dependency_type] == nil then
            removed[dependency_type] = [repo_dependency_directory]
          else
            removed[dependency_type] << repo_dependency_directory
          end
        end
      end
    end
  end
end

File.open("#{filter_results_dir}/removed_directories.json", 'w') do |file|
  file << JSON.dump(removed)
end
