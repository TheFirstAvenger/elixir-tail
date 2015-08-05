Tail
====

Tail implements a simple file tail functionality.

Given a file, a function, and an interval, Tail will execute the function for each line in the file
and continue checking for additional lines on the interval.

## Usage

    {:ok, pid} = Tail.start_link("test.txt", &IO.inspect(&1))

    Tail.stop(pid)