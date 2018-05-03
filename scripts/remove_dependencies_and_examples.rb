require 'fileutils'
require 'json'

def remove_directory repository, dependency_type, dependency_directories, removed
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
      # search for dependency code directories with case-sensitive search
      ['Pods', 'Carthage'].each do |dependency_type|
        dependency_directories = `find . -type d -name "#{dependency_type}"`
        remove_directory repository, dependency_type, dependency_directories, removed
      end

      # search for auxiliary code directories with case-insensitive search
      ['*Example*', '*Test*', '*Demo*', '*.playground'].each do |dependency_type|
        dependency_directories = `find . -type d -iname "#{dependency_type}"`
        remove_directory repository, dependency_type, dependency_directories, removed
      end
    end
  end
end

File.open("#{filter_results_dir}/removed_directories.json", 'w') do |file|
  file << JSON.dump(removed)
end
