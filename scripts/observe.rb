require 'json'

def massage_results input
  input.split("\n").delete_if{|x|x.empty?}.map{|x|x.strip}
end

observations_metadata_dir = 'observations'
`mkdir -p #{observations_metadata_dir}`

repositories_dir = 'repositories'
Dir.entries(repositories_dir).each do |repository|
  next if repository == '.' || repository == '..' || repository == '.DS_Store'
  
  declarations = Hash.new
  Dir.chdir("#{repositories_dir}/#{repository}") do
    declarations["function"] = massage_results `ag -swQ --swift --nofilename --nogroup func | ag -svwQ override`
    declarations["enum"] = massage_results `ag -swQ --swift --nofilename --nogroup enum`
    declarations["extension"] = massage_results `ag -swQ --swift --nofilename --nogroup extension`
    declarations["protocol"] = massage_results `ag -swQ --swift --nofilename --nogroup protocol`
    declarations["struct"] = massage_results `ag -swQ --swift --nofilename --nogroup struct`
    declarations["class"] = massage_results `ag -swQ --swift --nofilename --nogroup class`
    declarations["typealias"] = massage_results `ag -swQ --swift --nofilename --nogroup typealias`
    declarations["operator"] = massage_results `ag -swQ --swift --nofilename --nogroup operator`
  end
  
  metadata_file = "#{observations_metadata_dir}/#{repository}.json"
  File.open(metadata_file, 'w') do |file|
    file << JSON.dump(declarations)
  end
end


