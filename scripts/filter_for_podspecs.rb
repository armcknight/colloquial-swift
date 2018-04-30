require 'json'

repos_with_podspecs = Array.new
Dir.chdir('repositories') do
  podspec_locations = `find . -depth 2 -name '*.podspec'`# newline-delimited list of paths in form './some_repo/some.podspec'
  repos_with_podspecs = podspec_locations.split("\n").map do |podspec_location|
    podspec_location.split('/')[1] # splits ./some_repo/some.podspec into ['.', 'some_repo', 'some.podspec']; need 'some_repo'
  end
end

File.open('observations/_repos_with_podspecs.txt', 'w') do |file|
  file << JSON.dump(repos_with_podspecs)
end