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

Not everything everyone wants can necessarily be a stdlib member. Swift has a proposal process called evolution: [https://github.com/apple/swift-evolution](https://github.com/apple/swift-evolution)

Why might people decide to write their own instead of using another?

- discoverability is hard
- reading others' code/docs is hard
- desire to be thought leader
- they didn't find an answer to their problem
- nobody has solved the problem
- they do not know something has been solved alrady, or that it is solvable
- they believe they can do a better job

Colloquial: people, and groups of people, think differently, or at least exhibit varied linguistics in how they communicate. That applies to programming languages as well. Apple has created API guidelines for swift to help keep the ecosystem more coherent: [https://swift.org/documentation/api-design-guidelines/](https://swift.org/documentation/api-design-guidelines/)

Conway's law for Swift: "organizations which design Swift libraries ... are constrained to produce APIs which are copies of the communication structures of these organizations".

Assumptions:

- most devs/teams have a "utility" type collection of helper code that is difficult to fit into a specialized collection or make stand on its own. even if it's just a holding place where things go to mature and eventually become something (or get removed), but they just don't fit anywhere at the time.

Hypothesis: despite the efforts to create a consistent ecosystem around the Swift language, there is wide variation in the coding and naming conventions amongst publicly available 3rd party swift libraries. If the problems we're solving are unique, then the code we write and use the most will have evolved sufficiently past the point where they closely resemble other similarly mature libraries.

Methodology:

- maintain a set of git URLs to repositories
    - discovery
        - web search specific companies
        - web search for lists of swift libraries
        - github search
            - perform searches using the github rest api
                - [https://developer.github.com/v3/search/#search-repositories](https://developer.github.com/v3/search/#search-repositories)
                - `scripts/github_search_queries.rb` performs all the queries and writes the results to disk under `github_search_results/`
                - processing results
                  - `scripts/convert_github_search_results_to_urls.rb` converts result json to lists of ssh cloning urls
                - for searches with more than 1000 results (at which github caps results), sort by fork/star count as well as the default ("best match")
            - characterize activity
                - using created/pushed qualifiers
            - searches
                - repo name containing "utility"
                - swift repo with "utility" in name
                - github topic is "utility": these repositories have deliberately marked themselves with the "utility" topic keyword
    - categorize by oss library, corporate offered library, oss app/corporate internal utilities collections
    - including forks might involve looking at the modifications; will not consider them
- script cloning all repositories under a root directory
- run observation scripts, outputting results
- visualize results

Swift Code Observations

- declarations
    - extension
      - collate by thing being extended
    - function
    - protocol
    - struct
    - enum
    - class
    - custom operators
- unicode identifiers
        - emoji
        - symbols
- trivia
    - longest function signature
    - longest identifier for enum/class/struct/protocol 
- testing
    - number of test functions
- dependencies
    - import statements, non-apple... do the utilities stand on their own?
    - cocoapods/carthage/spm support and usage
    - usage of git submodules

Results

- 99,601 total repos with "utility" in name, as of 4/5/2017; swift not in top 10, where the two distant leaders are python and javascript

swift libraries:

- [https://github.com/SwifterSwift/SwifterSwift](https://github.com/SwifterSwift/SwifterSwift)
- [https://github.com/IanKeen/Components](https://github.com/IanKeen/Components)
- [https://github.com/davedelong/Syzygy](https://github.com/davedelong/Syzygy)
- [https://github.com/TwoRingSoft/Pippin/tree/develop/Sources/Pippin/Extensions](https://github.com/TwoRingSoft/Pippin/tree/develop/Sources/Pippin/Extensions)
- [https://github.com/FabrizioBrancati/BFKit-Swift](https://github.com/FabrizioBrancati/BFKit-Swift)
- [https://github.com/raywenderlich/swift-algorithm-club (sort of)](https://github.com/raywenderlich/swift-algorithm-club (sort of))
- [https://github.com/practicalswift/Pythonic.swift](https://github.com/practicalswift/Pythonic.swift)

company swift libraries:

- [https://github.com/kickstarter/Kickstarter-Prelude](https://github.com/kickstarter/Kickstarter-Prelude)

internal utility libraries:

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


Should we change the word "utility"? If we use it as a place to let small ideas grow, then we can call it something like... well, playground, but that's taken... garden? Incubator?