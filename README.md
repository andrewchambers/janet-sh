# janet-sh

## Quick example

```
(import sh)

# raise an error on failure.
(sh/$ ["touch" "foo.txt"])

# raise an error on failure, return command output.
(sh/$$ ["echo" "hello world!"])
@"hello world!\n"

# return true or false depending on process success.
(when (sh/$? ["true"])
  (print "cool!"))

# shell helpers

(sh/shell-quote ["hello" "there ' \""])
"'hello' 'there '\\'' \"'"

(sh/pipeline [["ls"] ["sort" "-u"]])
@["/bin/sh" "-c" "'ls' | 'sort' '-u'"] # pass this to a run function.
```
