# janet-sh

The rationale and design is partially covered in a [blog post](https://acha.ninja/blog/dsl_for_shell_scripting/)

## Quick examples

```janet
(import sh)

# raise an error on failure.
(sh/$ touch foo.txt)

# raise an error on failure, return command output.
(sh/$< echo "hello world!")
"hello world!\n"

# return true or false depending on process success.
(when (sh/$? true)
  (print "cool!"))

# pipelines
(sh/$ cat ,path | sort | uniq)

# pipeline matching
(match (sh/run yes | head -n5)
  [0 0] :ok)

# run a command in a real shell (your system's `sh`)
(sh/sh cd /tmp && git clone https://github.com/andrewchambers/janet-sh)

# use shell variables in a real shell
(sh/sh<
  if [ "${USER}" = ,(os/getenv "USER") ];
  then echo "it's \"me\""; else echo "not me"; fi)
```
