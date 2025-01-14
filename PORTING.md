### Porting code from joshbuddy/jsonpath

The only other serious ruby implementation of jsonpath is [joshbuddy/jsonpath](https://github.com/joshbuddy/jsonpath), also known as the ruby gem "jsonpath".

The jsonpath gem has been around since 2008 and was implemented at a time when there was not even a draft version of the standard.
It is not compliant with the jsonpath RFC 9535, which was finalized much later in 2024.

The jsonpath gem has features that janeway does not, such as:

    * deletion of the values through jsonpath queries
    * handling of hashes with symbol keys
    * handling of nested objects responding to `#dig`, such as Structs
    * modification of values specified by jsonpath

Janeway currently only does strict RFC-compliant queries that return values.

I personally have used joshbuddy/jsonpath for several years.
Now I've ported one of my own projects from joshbuddy/jsonpath to janeway.
The process revealed several jsonpath queries I had been using that aren't valid unter RFC-compliant jsonpath and had to be updated.

Here are the ones I found.

### Input json

Since joshbuddy/jsonpath provides the command-line tool `jsonpath` for executing queries, it's simplest to demonstrate these examples on the command-line.

For the queries that reference the "store", you can run the same queries using this json data from the [original jsonpath article by Goessner](https://goessner.net/articles/JsonPath/):

```json
{
    "store": {
        "book": [ 
            { "category": "reference",
                "author": "Nigel Rees",
                "title": "Sayings of the Century",
                "price": 8.95
            },
            { "category": "fiction",
                "author": "Evelyn Waugh",
                "title": "Sword of Honour",
                "price": 12.99
            },
            { "category": "fiction",
                "author": "Herman Melville",
                "title": "Moby Dick",
                "isbn": "0-553-21311-3",
                "price": 8.99
            },
            { "category": "fiction",
                "author": "J. R. R. Tolkien",
                "title": "The Lord of the Rings",
                "isbn": "0-395-19395-8",
                "price": 22.99
            }
        ],
        "bicycle": {
            "color": "red",
            "price": 19.95
        }
    }
}
```

### Differences

* joshbuddy/jsonpath allows unquoted strings in filter comparisons.
Janeway requires string literals to be quoted.

Examples:
```
    $ jsonpath '$.store.book[?(@.category==reference)]' example.json
    $ janeway  '$.store.book[?(@.category=="reference")]' example.json
```

* joshbuddy/jsonpath allows root selector to be omitted.

Examples:
```
    $ jsonpath 'store' example.json
    $ janeway '$.store' example.json
```

* joshbuddy/jsonpath treats name selector within a filter selector as a value check, not an existence check

Consider this input json, which has objects with an "x" key that can have a true or false value.

```json
{ "a": { "x": true }, "b": { "x": false } }
```

joshbuddy/jsonpath considers the query `$.*[?(@.x)` to match only object "a", because a's value for key "x" is true.
Janeway considers this same query to match both objects, because both objects have a key "x". The key value is not considered, beacuse "@.x" is an existence check.

To make an equivalent query for janeway, explicitly compare the value with `true`:

```
    $ jsonpath '$.*[?(@.x)]' document.json
    $ janeway '$[?(@.x==true)]' document.json
```

Notice one other difference in the query above:

The `jsonpath` tool's query starts with `$.*`, but the `janeway` query omits that.
According to the RFC, the wilcard operator "*" would convert the JSON Object to a list of the values from the object, discarding the keys.  Thus, the "x" key would be thrown away and the "`@.x`" part of the query wouldn't be able to match on it.


* jsonpath requires parentheses around the filter selector, janeway does not
Examples:
```
    $ jsonpath '$.store.book[?(@.category==reference)]' example.json
    $ janeway  '$.store.book[? @.category=="reference"]' example.json
```
The spaces can be omitted too, or more added.


No doubt there are other differences that I haven't found.  Feel free to open bug requests or PRs to add more.
