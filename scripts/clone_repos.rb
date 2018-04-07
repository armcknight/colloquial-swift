urls_dir = 'ssh_urls'
repositories_dir = 'repositories'
`mkdir -p #{repositories_dir}`

Dir.entries(urls_dir).each do |url_list|
  next if url_list == '.' || url_list == '..' || url_list == '.DS_Store'
  
  url_list_path = "#{urls_dir}/#{url_list}"
  File.open(url_list_path, 'r') do |url_list_file|
    Dir.chdir(repositories_dir) do
      url_list_file.each_line do |url|
        repo_full_name = url.gsub('git@github.com:','').gsub('.git','').gsub('/','_')
      
        # clone repo
        `git clone --depth 1 -- #{url.strip} #{repo_full_name}`
      end
    end
  end
end


