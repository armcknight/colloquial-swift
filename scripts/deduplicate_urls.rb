urls_directory = 'ssh_urls'
`cat #{urls_directory}/*.txt | sort | uniq > #{urls_directory}/_common.txt`
