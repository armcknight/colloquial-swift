require 'json'

# return the total count of results for the search
def make_call_with_query query, page
  search_id = query.gsub('+', '__').gsub(':', '_')
  result_dir = "github_search_results/#{search_id}"
  `mkdir -p #{result_dir}`
  result_path = "#{result_dir}/#{page}.json"
  command = "curl -H \"Accept: application/vnd.github.mercy-preview+json\" \"https://api.github.com/search/repositories?q=#{query}+language:swift&page=#{page}&per_page=100\""
  puts command
  json_result = `#{command}`
  parsed_json = JSON.parse(json_result)
  File.open(result_path, 'w') do |file|
    file << json_result
  end
  parsed_json['total_count'].to_i
end

def run_all_queries
  queries = [
    'util',
    'tool',
    'helper',
    'extension',
    'framework',
    'library',
    'wrapper',
    'easy',
    'app+stars%3A0',
    'app+stars%3A1',
    'app+stars%3A2',
    'app+stars%3A3',
    'app+stars%3A4',
    'app+stars%3A5..10',
    'app+stars%3A11..100',
    'app+stars%3A%3E101',
  ].map{ |query|
    [ query + '+in:name', 'topic:' + query ]
  }.flatten
  queries << 'easier+in:description'

  queries.each do |query|
    # depending on the result count, perform paginated search queries to get up to the first 1000 results (github doesn't provide more than that)
    count = make_call_with_query query, 1
    puts "results: #{count}"
    if count > 100 then
      pages = count / 100 + ((count % 100 == 0) ? 0 : 1)
      pages = 10 if pages > 10 # github only exposes the first 1000 results per search: 10 pages x 100 results per page
      puts "pages: #{pages}"
      2.upto(pages) do |page|
        sleep 10 # github search query rate limits unauthenticated requests to 6 per minute
        make_call_with_query query, page
      end
    end
  end
end

run_all_queries
