Swift Babel

Writing libraries of reusable code allows us to work more quickly, avoiding reinventing wheels

Everyone writing their own library for themselves is in and of itself reinventing wheels

What if we could all share the same utility and wrapper libraries? It would be a singular wrapper around UIKit/Foundation.

Then what is the difference between that and the standard SDKs they're wrapping?

- UIKit is 
	- a wrapper around lower level C routines that handle the actual drawing of pixels, that provides patterns and vocabulary to create complex interfaces that harness the wrapped technologies
	- an extension to what is possible to draw on a screen from the raw tools of the wrapped tech
		- even if "extension" is subjective, like enhanced code expressibility via syntax sugar or alternative syntax
- This new "public" SDK would wrap "lower level" UIKit/Foundation constructs into common usages. It would have its own patterns and vocabulary, and would extend the capabilities of the underlying technologies.

This middle ground is usually filled by something called a stdlib, a collection of functionality that is not part of the language itself. The language is just the set of keywords and punctuation that the compiler knows how to translate into machine code. It's like spoken/written languages like English or Chinese: the novels written in each are the stdlibs, and our utility libraries are like facebook comment sections for each book.

- java: 
- kotlin: [https://kotlinlang.org/api/latest/jvm/stdlib/index.html \](https://kotlinlang.org/api/latest/jvm/stdlib/index.html)
- swift: 
- c++:
- ruby:
- python:
- javascript: 

Not everything everyone wants can necessarily be a stdlib member. Swift has a proposal process called evolution: [https://github.com/apple/swift-evolution](https://github.com/apple/swift-evolution). This process necessarily has friction, so it's much easier to write something you really want right now in your own code. Since you want to be able to reuse it, you put it in your utility belt.

Why might people decide to write their own instead using and contributing to another?

- discoverability is hard
- reading others' code/docs is hard
- desire to be thought leader
- they didn't find an answer to their problem
- nobody has solved the problem
- they do not know something has been solved alrady, or that it is solvable
- they believe they can do a better job

It's hard to imagine that each person's or team's utility belt are very similar. 

Conway's law for Swift: "organizations which design Swift libraries ... are constrained to produce APIs which are copies of the communication structures of these organizations".

Colloquial: people, and groups of people, think differently, or at least exhibit varied linguistics in how they communicate. That applies to programming languages as well. Apple has created API guidelines for swift to help keep the ecosystem more coherent: [https://swift.org/documentation/api-design-guidelines/](https://swift.org/documentation/api-design-guidelines/)

The same is true of documentation, something else developers must write, but comes in various styles, even just considering those written by native speakers of a particular language. This may even be observed on one team: some people paint lush images with flowery words in descriptive prose worthy of any salesman, others write series of tacit statements that may as well be program code itself (I tend to fall into the latter camp).

## Experiment

### Assumptions

- most devs/teams have a "utility" type collection of helper code that is difficult to fit into a specialized collection or make stand on its own. 
- it's often just a holding place where things go to mature and eventually become something (or get removed), but they just don't fit anywhere at the time... if so, should we change the word "utility"? If we use it as a place to let small ideas grow, then we can call it something like... well, playground, but that's taken... garden? Incubator? Evolution?

### Hypothesis

despite the efforts to create a consistent ecosystem around the Swift language, there is wide variation in the coding and naming conventions amongst publicly available 3rd party swift libraries. If the problems we're solving are unique, then the code we write and use the most will have evolved sufficiently past the point where they closely resemble other similarly mature libraries.

### Methodology

#### Data set curation

- ✅ collect set of git URLs to repositories
	- including forks might involve looking at the modifications; will not consider them
	- manual
		- web search repos 
		- search companies' github accounts for utilities
		- web search for lists of swift libraries
		- script extraction of github repo urls from lists
		- keep manual list in `ssh_urls/_manual.txt`
	- automatic: github search rest api: [https://developer.github.com/v3/search/#search-repositories](https://developer.github.com/v3/search/#search-repositories)
		- ✅ repository search
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
		- processing results
			- ✅ `scripts/gather_ssh_urls.rb` converts result json to lists of ssh cloning urls
			- ✅ pull desired repo metadata out of paged results, into one large JSON array `scripts/combine_search_results.sh`
- ✅ clone repositories
	- clone all to one flat repo: `scripts/clone_repos.rb`
- ✅ remove dependency and example code `scripts/remove_dependencies_and_examples.rb`
	- lots of Pods/ and Carthage/ directories will be checked in; remove them after cloning
	- remove example/demo directories, which may contain their own dependencies too
	- remove playground and test directories also
	- no need to worry about git submodules, we never sync them as part of cloning
- ✅ filter repositories
	- not all repositories will be relevant, many test/experimentation/example repos, or personal apps
	- only select repositories with a podspec (some have more than one)
	- `scripts/filter_for_podspecs.rb`
- `swiftc -dump-parse` and/or `swiftc -print-ast`
	- gets structured, canonical forms of declarations/etc in S-expressions (`-dump-parse`) or ASTs (`-print-ast`)
	- parse in the ruby scripts with [sxp](https://github.com/dryruby/sxp.rb)?
	- helps filter out commented declarations and other non-specific text containing a keyword used in the text search (e.g. searching with 'extension' turns up extension declarations but also any comments containing the word, etc)
- extract observations
	- text search (`ag`, the silver searcher) to grab raw lines of code

#### Observations

- code
	- declarations
		- ✅ extension
			- ✅ collate by thing being extended `jq '.declarations.extension' ../observations/*.json 2>/dev/null | grep extension | sort | uniq -c | sort`
				- separate into extensions on Apple vs. non-Apple API
		- ✅ function 
			- (non-XCTest)
			- collate by thing being extended
			- ✅ filter out overrides to avoid functions we know weren't written by the lib developer
		- ✅ protocol
		- ✅ struct
		- ✅ enum
		- ✅ class
		- ✅ custom operators
		- ✅ typealiases
		- advanced language features
			- generics
			- associatedtype
			- protocol conformance masks (& operator)
			- access modifiers (public, private, open etc)
			- attributes (@discardableResult, @objc, @escaping, @autoclosure etc)
	- error throwing
	- comments
		- ✅ inline, inline swift doc, multiline, headerdoc
		- use of headerdoc keywords
		- comment markers e.g. MARK, TODO, FIXME
	- ✅ swift file lines-of-code counts
		- ✅ avg, min, max
	- unicode identifiers
		- emoji
		- symbols
	- trivia
		- longes/shortest identifier for enum/class/struct/protocol/function/operator
		- longest/shortest swift file
- repository
	- contains playgrounds?
	- swift version
	- number of stars, forks, pull requests
	- dependencies
		- import statements, non-apple... do the utilities stand on their own?
		- cocoapods/carthage/spm support and usage
		- usage of git submodules
- testing
	- number of test functions

- text analysis
	- types of analysis
		- sentiment
		- readability
		- time to read
	- on components
		- github description
		- readmes
		- comments
		- by declaration type

- metrics
	- encode conformance/violation of api guidelines

- segment per github search

### Results

venn diagram generator: http://www.biovenn.nl/index.php

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

- all extension declarations, counting duplicates: `jq '.declarations.extension' ../observations/*.json 2>/dev/null | grep extension | sort | uniq -c | sort`

- looking for common tasks
	- image operations
	- colors
		- `jq '.declarations.function.parsed[].identifier' ../observations/*.json 2>/dev/null | grep -i UIColor | sort | uniq -c | sort`
	- core graphics
	- frame logic
	- autolayout
	- core data
	- dictionaries
	- arrays
	- dates
	- gestures
	- sets
	- files
	- serialization
		- plist
		- json
		- xml
	- strings
	- hashing
	- notifications
	- kvo
	- user defaults
	- webkit and webviews
	- maps
	- bundles
	- networking
	- uikit
		- device stuff
		- alerts
		- collection views
		- table views
		- buttons
		- modals
		- 
	- location manager
	- device motion
	- avfoundation
	- 

### Conclusions

- 

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
