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

# pipelines
(sh/$ '[sort] : '[uniq])

# pipeline matching
(match (sh/run '[yes] : '[head -n5])
  [_ 0] :ok)

```