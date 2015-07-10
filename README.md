Tail
====

Tail implements a simple file tail functionality.

Given a file, a function, and an interval, Tail will execute the function for each line in the file
and continue checking for additional lines on the interval.

## Usage

    {:ok, pid} = Tail.start_link("test.txt", &IO.inspect(&1), 1000)

    Tail.stop(pid)

## Notes
Note that Tail's current implementation scans the entire file twice whenever the modfified time on the file changes.