def clone_repo url, dir
  repo_full_name = url.gsub('git@github.com:','').gsub('.git','').gsub('/','_')
  Dir.chdir(dir) do
    `git clone --depth 1 -- #{url.strip} #{repo_full_name}`
  end
end

urls_dir = 'ssh_urls'
repositories_dir = 'repositories'
clones_dir = "#{repositories_dir}/_all"
`mkdir -p #{clones_dir}`

# get list of common urls: urls appearing in more than one list
common_url_list_file = '_common.txt'
common_urls = Array.new
File.open("#{urls_dir}/#{common_url_list_file}", 'r') do |file|
  file.each_line do |url|
    common_urls << url
  end
end

Dir.entries(urls_dir).each do |url_list|
  next if url_list == '.' || url_list == '..' || url_list == '.DS_Store'
  
  if url_list == common_url_list_file then
    # clone all the common repos
    common_urls.each do |url|
      clone_repo url, clones_dir
    end
  else
    url_list_path = "#{urls_dir}/#{url_list}"
    File.open(url_list_path, 'r') do |url_list_file|
      url_list_file.each_line do |url|
        # create symlinks for all repos
        repo_full_name = url.gsub('git@github.com:','').gsub('.git','').gsub('/','_')
        search_id = url_list.gsub('.txt','')
        
        symlinks_dir = "#{repositories_dir}/#{search_id}"
        `mkdir -p #{symlinks_dir}`
        
        destination_path = "#{clones_dir}/#{full_repo_name}"
        source_path = "#{symlnks_dir}/#{repo_full_name}"
        `ln -s #{destination_path} #{source_path}`

        # clone each repo not already cloned from common  
        next if common_urls.include?(url)
        clone_repo url, clones_dir
      end
    end
  end
end


