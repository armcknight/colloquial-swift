all_repositories = Dir.entries('observations').select{|x| x != '.' || x != '..' || x != '.DS_Store'}

# chunk up the set of repos to process so `jq` doesn't run out of memory
stride = 500
start_i = 0
end_i = stride - 1
repo_count = all_repositories.size
repo_sets = Array.new
while start_i < repo_count do
  end_i = repo_count - 1 if end_i >= repo_count
  next_set = all_repositories[start_i..end_i]
  repo_sets << next_set
  start_i = end_i + 1
  end_i += stride
end

repo_sets.each do |repo_set|
  repo_set.each do |repository|
    next if repository == '.' || repository == '..' || repository == '.DS_Store'

    # sum counts of extension groups to include extensions for protocol conformance or generic where clauses
    `jq '.declarations.extension.parsed[].identifier' observations/*.json | sort | uniq -c | sort | grep -w String | awk -F ' ' '{sum+=$0} END {print sum}'`


    # count extensions, including protocol conformations and where clauses involving certain API
    `jq '.declarations.extension.parsed[].identifier' observations/*.json | sort | uniq -c | sort | grep React | awk -F ' ' '{sum+=$0} END {print sum}'`

    #drilling down into extensions on String (as an example case)

    # count repos with a String extension
    `jq '. | select(.declarations.extension.parsed[].identifier=="String") | .repository.full_name' observations/*.json | sort | uniq | wc -l`

    # count total amount of extension functions
    `jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' observations/*.json | wc -l`

    # count function signatures grouped by uniq
    `jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' observations/*.json | sort | uniq -c | sort`

    # whittling away by keyword (e.g., all the functions _except_ trim/substring functions)
    `jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' observations/*.json | grep -vi -e trim -e substring | sort | uniq -c | sort`
    
    

    # looking at common tasks, e.g. trimming

    # count signatures containing a keyword by uniq
    `jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' observations/*.json | sort | uniq -c | sort | grep -i trim`

    # sum counts of grouped signatures
    `jq '.declarations.extension.parsed[] | select(.identifier=="String") | .declarations | .function.parsed[].identifier' observations/*.json | sort | uniq -c | sort | grep -i trim | awk -F ' ' '{sum+=$0} END {print sum}'`

    # search for implementations of a particular function signature
    `ag --swift --after=10 --literal "trim() -> String" 2>/dev/null`

    # grab the return statements from the 10 lines following each text match of the signature, sort, count by uniq
    `ag --nofilename --swift --after=3 --literal "trim() -> String" 2>/dev/null | grep return | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sort | uniq -c | sort`
    
  end
end
