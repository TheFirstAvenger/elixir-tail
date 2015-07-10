defmodule TailTest do
  use ExUnit.Case

  @path "testfile"

  setup_all do
    on_exit fn ->
      File.rm(@path)
    end
  end

  test "tail a single line, already-closed file" do
    text = "This is some test text\n"
    File.write(@path, text)

    {:ok, agent_pid} = Agent.start(fn -> nil end)

    {:ok, pid} = Tail.start_link(@path, fn output ->
      Agent.update(agent_pid, fn _state -> output end)
    end)

    task = Task.async(fn ->
      :timer.sleep(100)
      Agent.get(agent_pid, &(&1))
    end)

    output = Task.await(task)

    assert output == text

    Tail.stop(pid)
  end

  test "tail a file still being appended to" do
    file = File.open!(@path, [:write])
    output = ["A\n", "B\n", "C\n", "D\n", "E\n", "F\n", "G\n"]

    {:ok, agent_pid} = Agent.start(fn -> [] end)

    {:ok, pid} = Tail.start_link(@path, fn output ->
      Agent.update(agent_pid, fn state -> state ++ [output] end)
    end)

    IO.write(file, Enum.at(output, 0))
    :timer.sleep(1000)

    assert Agent.get(agent_pid, &(&1)) == Enum.take(output, 1)

    IO.write(file, Enum.at(output, 1))
    :timer.sleep(1000)

    assert Agent.get(agent_pid, &(&1)) == Enum.take(output, 2)

    IO.write(file, Enum.at(output, 2))
    :timer.sleep(1000)

    assert Agent.get(agent_pid, &(&1)) == Enum.take(output, 3)

    IO.write(file, Enum.at(output, 3))
    :timer.sleep(1000)

    assert Agent.get(agent_pid, &(&1)) == Enum.take(output, 4)

    Tail.stop(pid)
  end
end
