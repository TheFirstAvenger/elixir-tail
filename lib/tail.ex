require Logger

defmodule Tail do
	@moduledoc """
	Tail implements a simple file tail functionality.

	Given a file, a function, and an interval, Tail will execute the function for each line in the file
	and continue checking for additional lines on the interval.

	## Usage

	{:ok, pid} = Tail.start_link("test.txt", &IO.inspect(&1), 1000)
	Tail.stop(pid)

	## Notes
	Note that Tail's current crude implementation scans the entire file twice on each interval.
	"""

	use GenServer


	@doc """
	Public interface. Starts a Tail Genserver for the given file, function, and interval
	"""
	def start_link(file, fun, interval) do
		GenServer.start_link(__MODULE__, {file, fun, interval})
	end

	@doc """
	Public interface. Sends a call to kill the GenServer
	"""
	def stop(pid) do
		GenServer.call(pid, :kill)
	end

	@doc """
	init callback. Starts the check loop by casting :check to self and then returns the initial state
	"""
	def init({file, fun, interval}) do
		GenServer.cast(self, :check)
    {:ok, {file, fun, interval, 0}}
	end

	@doc """
	Main loop. Calls check_for_lines, sleeps, then continues the loop by casting :check to self
	and returning with the (possibly updated) position
	"""
	def handle_cast(:check, {file, fun, interval, position}) do
		position = check_for_lines(file, fun, position)
		:timer.sleep(interval)
		GenServer.cast(self, :check)
    {:noreply, {file, fun, interval, position}}
	end

	@doc """
	Handles :kill call. Checks for any final lines before stopping the genserver
	"""
	def handle_call(:kill, _from, {file, fun, interval, position}) do
		position = check_for_lines(file, fun, position)
    {:stop, :normal, {file, fun, interval, position}}
	end

	#Crude implementation of line checking. Stream.drop(position) skips lines previously read, then Enum.each applies
	#the specified function to each line. Enum.count returns the new position. If the file doesn't exist, it simply returns
	#the given position, assuming the file will appear eventually.
	defp check_for_lines(file, fun, position) do
		if !File.exists?(file) do
			position
		else
			stream = File.stream!(file)
			stream
			|> Stream.drop(position)
			|> Enum.each(&fun.(&1))
			Enum.count(stream)
		end
	end
end
