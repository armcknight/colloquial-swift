# Colloquial Swift

## Background

Not every code construct people want can necessarily be a swiftlang/stdlib member. Swift has a proposal process called Evolution: [https://github.com/apple/swift-evolution](https://github.com/apple/swift-evolution). This process necessarily has friction, so it's much easier to write something you really want right now in your own code. Since you want to be able to reuse it, you put it in your utility belt. Writing libraries of reusable code allows us to work more quickly, avoiding reinventing wheels.

Why might people decide to write their own instead using and contributing to another?

- reading others' code/docs is hard
- desire to be a thought leader
- they didn't find an answer to their problem
- nobody has solved the problem
- they do not know something has been solved alrady, or that it is even solvable
- they believe they can do a better job

Colloquial: people, and groups of people, think differently, or at least exhibit varied linguistics in how they communicate. That applies to programming languages as well. Apple has created API guidelines for Swift to help keep the ecosystem more coherent: [https://swift.org/documentation/api-design-guidelines/](https://swift.org/documentation/api-design-guidelines/)

Conway's law for Swift: "organizations which design Swift libraries ... are constrained to produce APIs which are copies of the communication structures of these organizations".

## Experiment

### Assumptions

- most devs/teams have a "utility" type collection of helper code that is difficult to fit into a specialized collection or make stand on its own
- these collections can also act as holding places where things go to mature and eventually are extracted to their own home

### Hypothesis

People are solving similar problems over and over again in their utility libraries.

### Methodology

#### Data set curation

- [x] collect set of git URLs to repositories
	- including forks might involve looking at the modifications; will not consider them
	- manual
		- web search repos 
		- search companies' github accounts for utilities
		- web search for lists of swift libraries
		- script extraction of github repo urls from lists
		- keep manual list in `ssh_urls/_manual.txt`
	- automatic: github search rest api: [https://developer.github.com/v3/search/#search-repositories](https://developer.github.com/v3/search/#search-repositories)
		- [x] repository search
			- searching
				- for queries returning more than 1000 results, let github decide the best 1000 instead of sorting by star/forks
				- queries
					- util
					- tool
					- extension
					- helper
					- framework
					- library
					- wrapper
					- easy
				- search types
					- keyword: default search type; searches for repos whose name contains the query term
						- one exception: search for repos with description containing 'easier'
					- topic: these repositories have deliberately marked themselves with the query term as one of their github "topics"
						- these topics exist but were not used because they contain other search terms already used:
							- swift-extensions
							- swift-wrapper
							- swift-library
							- swift-framework
				- all searches are confined to repos that github recognizes as swift codebases
				- `scripts/github_search_queries.rb` performs all the queries and writes the results to disk under `github_search_results/`, in subdirectories named as a unique id made of the search terms
		- [x] processing results
			- `scripts/gather_ssh_urls.rb` converts result json to lists of ssh cloning urls
			- pull desired repo metadata out of paged results, into one large JSON array `scripts/combine_search_results.sh`
- [x] clone repositories: `scripts/clone_repos.rb`
- [x] remove dependency and example code `scripts/remove_dependencies_and_examples.rb`
	- lots of Pods/ and Carthage/ directories will be checked in; remove them after cloning
	- remove example/demo directories, which may contain their own dependencies too
	- remove playground and test directories also
	- no need to worry about git submodules, we never sync them as part of cloning
- [x] filter repositories
	- not all repositories will be relevant, many test/experimentation/example repos, or personal apps
	- only select repositories with a podspec (some have more than one)
	- `scripts/filter_for_podspecs.rb`
- [x] `swiftc -print-ast`
	- gets structured, canonical forms of declarations
	- helps filter out commented declarations and other non-specific text containing a keyword used in the text search (e.g. searching with 'extension' turns up extension declarations but also any comments containing the word, etc)
- extract observations
	- text search (`ag`, the silver searcher) to grab raw lines of code

#### Observations

- [ ] code
	- [ ] declarations
		- [x] extension with signature frequencies
			- [x] count total and uniques 
			- [x] non cocoa classes (e.g. UIImage, CLLocationManager) (swift team not likely to accept new api for these)
				- [x] count total and uniques
			- [x] group by api (top N extended apis)
				- [x] functions
					- [x] with signature frequencies
					- [x] count total and uniques
					- [ ] count repos containing the declaration
					- [x] tokenize function names and [ ] parameter labels by underscores, camel case and numeric digit substrings
						- [x] count unique word frequencies and total
						- [ ] count repos containing the keyword in a function name
						- [x] index into function lists with function frequencies, to cluster them by semantics
						- nice to haves:
							- [ ] cluster by anagrams and/or edit distance to group typos? (Double/Duoble/Duble)
							- [ ] cluster by synonyms
								- [ ] counts and distributions
							- [ ] note usage of '_', different parameter labels and names, same labels and names, absence of labels
							- [ ] note generics, blocks, return values
				- [x] repositories with extension frequencies
					- [x] count total
		- [ ] functions
			- [x] declarations
			- [ ] parameters 
				- [ ] counts and distributions per:
					- [ ] repo
					- [ ] 
			- [ ] closures
			- [ ] error throwing
				- [ ] throws
				- [ ] rethrows
		- [x] protocol
		- [x] struct
		- [x] enum
		- [x] class
		- [x] custom operators
		- [x] typealiases
		- [ ] generics
		- [ ] associatedtype
		- [ ] protocol conformance masks (& operator)
		- [ ] access modifiers (public, private, open, final, static etc)
		- [ ] attributes (@discardableResult, @objc, @escaping, @autoclosure, @available, @inlinable etc)
	- [ ] comments
		- [x] inline, inline swift doc, multiline, headerdoc
		- [ ] use of headerdoc keywords
		- [ ] comment markers e.g. MARK, TODO, FIXME
	- [x] swift file lines-of-code counts
		- [x] avg, min, max
	- [ ] unicode identifiers
		- [ ] emoji
		- [ ] symbols
	- [ ] trivia
		- [ ] longes/shortest identifier for enum/class/struct/protocol/function/operator
		- [ ] longest/shortest swift file
	- [ ] testing
		- [ ] number of test functions
	- [ ] generation
		- [ ] gyb
		- [ ] sourcery

- repository
	- contains playgrounds?
	- swift version
	- number of stars, pull requests
	- forks
		- counts
		- fork tree statistics (to describe forks-of-forks or shifts of activity to downstream forks)
			- depth
			- balance
		- activity statistics:
		- diff analysis between forks
	- dependencies
		- import statements, non-apple... do the utilities stand on their own?
		- cocoapods/carthage/spm support and usage
		- usage of git submodules

- text analysis
	- types of analysis
		- sentiment
		- readability
		- time to read
	- apply to components:
		- github description
		- readmes
		- comments
		- by declaration type

- metrics
	- encode conformance/violation of api guidelines

- group/segment results per: 
	- github search

### Results

- github search api results
	- the sum of all (retrievable) search hits (plus my own hand-curated list) is 4917, with 4774 unique repositories, so the searches are almost completely nonoverlapping; only a maximum of 143 repos appeared in more than one search, about 3% of the total
	- total: 6053 (`cat ssh_urls/*.txt | wc -l`)
	- unique: 5810 (`cat ssh_urls/*.txt | sort | uniq | wc -l`)
	- by search query:
		- keyword in name
			- extension: 1030
			- tool: 681
			- library: 661
			- framework: 593
			- helper: 559
			- easy: 549
			- util: 484
			- wrapper: 113
		- keyword in description
			- easier: 1607
		- topic
			- framework: 151
			- library: 111
			- extension: 70
			- wrapper: 30
			- tool: 24
			- util: 2
			- easy: 6
			- helper: 11
			

- removing Pods/Carthage/example/test directories
	- before: 535,825 files, 39.6 GB
	- after: 285,397 files, 22.72 GB
	- number of removed directories
		- test: 4787
		- example: 1622
		- demo: 990 
		- pods: 916
		- carthage: 154

- repositories with podspecs: 1357 (`jq '.[]' observations/_repos_with_podspecs.txt | wc -l`)

## Manual curation

- extension of a third party library: [https://github.com/SwiftyJSON/Alamofire-SwiftyJSON](https://github.com/SwiftyJSON/Alamofire-SwiftyJSON)

internal utility collections:

- [https://github.com/wordpress-mobile/WordPress-iOS/tree/develop/WordPress/Classes/Utility](https://github.com/wordpress-mobile/WordPress-iOS/tree/develop/WordPress/Classes/Utility)
- [https://github.com/kickstarter/ios-oss/tree/master/Kickstarter-iOS/TestHelpers (interesting, because they offer a separate swift utility library in its own repo)](https://github.com/kickstarter/ios-oss/tree/master/Kickstarter-iOS/TestHelpers (interesting, because they offer a separate swift utility library in its own repo))

lists of swift libraries:

- [https://github.com/vsouza/awesome-ios (especially "Utility")](https://github.com/vsouza/awesome-ios (especially "Utility"))
- [https://github.com/Wolg/awesome-swift (especially "Extensions")](https://github.com/Wolg/awesome-swift (especially "Extensions"))
- [https://github.com/matteocrippa/awesome-swift (many specialization categories; see "Utility" and "Kit" sections for extension-specific stuff)](https://github.com/matteocrippa/awesome-swift (many specialization categories; see "Utility" and "Kit" sections for extension-specific stuff))
- [https://medium.mybridge.co/39-open-source-swift-ui-libraries-for-ios-app-development-da1f8dc61a0f (ui libraries)](https://medium.mybridge.co/39-open-source-swift-ui-libraries-for-ios-app-development-da1f8dc61a0f (ui libraries))
swift.libhunt.com (particularly [https://swift.libhunt.com/categories/932-utility; there is also https://ios.libhunt.com)](https://swift.libhunt.com/categories/932-utility; there is also https://ios.libhunt.com))
- [https://www.freelancer.com/community/articles/41-open-source-swift-ui-libraries-for-ios-development (no utility type libraries though)](https://www.freelancer.com/community/articles/41-open-source-swift-ui-libraries-for-ios-development (no utility type libraries though))

newsletters:

- [https://www.getrevue.co/profile/publicextension](https://www.getrevue.co/profile/publicextension)
