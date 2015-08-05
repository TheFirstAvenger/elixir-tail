require Logger

defmodule Tail do
	@moduledoc """
	Tail implements a simple file tail functionality.

	Given a file, a function, and an interval, Tail will execute the function with a list of new lines found
  in the file	and continue checking for additional lines on the interval.

	## Usage

	{:ok, pid} = Tail.start_link("test.txt", &IO.inspect(&1), 1000)
	Tail.stop(pid)
	"""

	use GenServer

  @type state :: {term, ([String.t]->), Integer, any, Integer}

	@doc """
	Public interface. Starts a Tail Genserver for the given file, function, and interval (in ms)
	"""
  @spec start_link(String.t, ([String.t]->), Integer) :: GenServer.on_start
	def start_link(file, fun, interval \\ 1000) do
		GenServer.start_link(__MODULE__, {file, fun, interval})
	end

	@doc """
	Public interface. Sends a call to kill the GenServer
	"""
  @spec stop(pid) :: :ok
	def stop(pid) do
		GenServer.call(pid, :kill)
	end

	#init callback. Starts the check loop by casting :check to self and then returns the initial state
  @spec init({String.t, ([String.t]->), Integer}) :: {:ok, state}
	def init({file, fun, interval}) do
		stream = File.stream!(file)
		GenServer.cast(self, :check)
    {:ok, {stream, fun, interval, nil, 0}}
	end

	
	#Main loop. Calls check_for_lines, sleeps, then continues the loop by casting :check to self
	#and returning with the (possibly updated) last_modified and position
  @spec handle_cast(:check, state) :: {:noreply, state}
	def handle_cast(:check, {stream, fun, interval, last_modified, position}) do
		{last_modified, position} = check_for_lines(stream, fun, last_modified, position)
		:timer.sleep(interval)
		GenServer.cast(self, :check)
    {:noreply, {stream, fun, interval, last_modified, position}}
	end

	#Handles :kill call. Checks for any final lines before stopping the genserver
  @spec handle_call(:kill, {pid, reference}, state) :: {:stop, :normal, :ok, state}
	def handle_call(:kill, _from, {stream, fun, interval, last_modified, position}) do
		{last_modified, position} = check_for_lines(stream, fun, last_modified, position)
    {:stop, :normal, :ok, {stream, fun, interval, last_modified, position}}
	end

	#Implementation of line checking. If the file doesn't exist, it simply returns the current state, assuming the
	#file will appear eventually. If the file hasn't been modified since last time, it also returns the current state.
	#If the file has been modified, Stream.drop(position) skips lines previously read, then Enum.each gathers the new lines.
	#Returns the new last_modified and position.
  @spec check_for_lines(term, ([String.t]->), term, Integer) :: {term, Integer}
	defp check_for_lines(stream, fun, last_modified, position) do
		cond do
			!File.exists?(stream.path) ->
				{last_modified, position}
			File.stat!(stream.path).mtime == last_modified ->
				{last_modified, position}
			true ->
				lines = stream
				|> Stream.drop(position)
				|> Enum.into([])
				if (length(lines) > 0) do
					fun.(lines)
				end
				{File.stat!(stream.path).mtime, position + length(lines)}
		end
	end
end