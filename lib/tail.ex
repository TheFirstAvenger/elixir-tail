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

  @type state :: {File.Stream.t(), ([String.t()] -> nil), integer, term, integer, integer}

  @doc """
  Public interface. Starts a Tail Genserver for the given file, function, and interval (in ms)
  """
  @spec start_link(String.t(), ([String.t()] -> nil), integer) :: GenServer.on_start()
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

  # init callback. Starts the check loop by casting :check to self and then returns the initial state
  @spec init({String.t(), ([String.t()] -> nil), integer}) :: {:ok, state}
  def init({file, fun, interval}) do
    stream = File.stream!(file)
    GenServer.cast(self(), :check)
    {:ok, {stream, fun, interval, nil, 0, 0}}
  end

  # Main loop. Calls check_for_lines, sleeps, then continues the loop by casting :check to self
  # and returning with the (possibly updated) last_modified and position
  @spec handle_cast(:check, state) :: {:noreply, state}
  def handle_cast(:check, state = {_stream, _fun, interval, _last_modified, _position, _size}) do
    state = check_for_lines(state)
    :timer.sleep(interval)
    GenServer.cast(self(), :check)
    {:noreply, state}
  end

  # Handles :kill call. Checks for any final lines before stopping the genserver
  @spec handle_call(:kill, {pid, term}, state) :: {:stop, :normal, :ok, state}
  def handle_call(:kill, _from, state) do
    state = check_for_lines(state)
    {:stop, :normal, :ok, state}
  end

  # Implementation of line checking. If the file doesn't exist, it simply returns the current state, assuming the
  # file will appear eventually. If the file hasn't been modified since last time, it also returns the current state.
  # If the file has been modified, Stream.drop(position) skips lines previously read, then Enum.each gathers the new lines.
  # Returns the new last_modified and position.
  @spec check_for_lines(state) :: state
  defp check_for_lines(state = {stream, fun, interval, last_modified, position, size}) do
    with {:exists, true} <- {:exists, File.exists?(stream.path)},
         {:ok, stat} <- File.stat(stream.path),
         {:mtime, true} <- {:mtime, stat.mtime != last_modified},
         {:size, true} <- {:size, stat.size >= size} do
      lines =
        stream
        |> Stream.drop(position)
        |> Enum.into([])

      if length(lines) > 0 do
        fun.(lines)
      end

      {stream, fun, interval, stat.mtime, position + length(lines), stat.size}
    else
      {:exists, false} -> {File.stream!(stream.path), fun, interval, last_modified, 0, 0}
      {:error, _} -> {File.stream!(stream.path), fun, interval, last_modified, 0, 0}
      {:size, false} -> {File.stream!(stream.path), fun, interval, last_modified, 0, 0}
      {:mtime, false} -> state
    end
  end
end
