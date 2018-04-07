require 'json'

function_metadata_dir = 'functions'
`mkdir -p #{function_metadata_dir}`

repositories_dir = 'repositories'
Dir.entries(repositories_dir).each do |repository|
  next if repository == '.' || repository == '..' || repository == '.DS_Store'
  
  function_declarations = Array.new
  Dir.chdir("#{repositories_dir}/#{repository}") do
    function_declarations = `ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`.split("\n").delete_if{|x|x.empty?}.map{|x|x.strip}
  end
  
  function_metadata_file = "#{function_metadata_dir}/#{repository}.json"
  File.open(function_metadata_file, 'w') do |file|
    file << JSON.dump(function_declarations)
  end
end


