defmodule TailTest do
  use ExUnit.Case

  @path "testfile"

  setup do
    on_exit(fn ->
      File.rm(@path)
    end)
  end

  test "tail a single line, already-closed file" do
    text = "This is some test text\n"
    File.write(@path, text)

    {:ok, agent_pid} = Agent.start(fn -> nil end)

    {:ok, pid} =
      Tail.start_link(@path, fn output ->
        Agent.update(agent_pid, fn _state -> output end)
      end)

    task =
      Task.async(fn ->
        :timer.sleep(100)
        Agent.get(agent_pid, & &1)
      end)

    output = Task.await(task)

    assert output == [text]

    Tail.stop(pid)
  end

  test "tail a file still being appended to" do
    output = ["A\n", "B\n", "C\n", "D\n", "E\n", "F\n", "G\n"]

    {:ok, agent_pid} = Agent.start(fn -> [] end)

    {:ok, pid} =
      Tail.start_link(
        @path,
        fn output ->
          Agent.update(agent_pid, fn state -> state ++ output end)
        end,
        220
      )

    File.write(@path, Enum.at(output, 0), [:append])
    :timer.sleep(1000)

    assert Agent.get(agent_pid, & &1) == Enum.take(output, 1)

    File.write(@path, Enum.at(output, 1), [:append])
    :timer.sleep(1000)

    assert Agent.get(agent_pid, & &1) == Enum.take(output, 2)

    File.write(@path, Enum.at(output, 2), [:append])
    :timer.sleep(1000)

    assert Agent.get(agent_pid, & &1) == Enum.take(output, 3)

    File.write(@path, Enum.at(output, 3), [:append])
    File.write(@path, Enum.at(output, 4), [:append])
    :timer.sleep(1000)

    assert Agent.get(agent_pid, & &1) == Enum.take(output, 5)

    Tail.stop(pid)
  end

  test "tail a file while its recreated" do
    check_tail_with_side_effect(fn ->
      assert :ok == File.rm(@path)
    end)
  end

  test "tail a file while its truncated" do
    check_tail_with_side_effect(fn ->
      assert :ok == File.write(@path, "")
      assert 0 == File.stat!(@path).size
    end)
  end

  def check_tail_with_side_effect(effect) do
    output = ["A\n", "B\n", "C\n", "D\n", "E\n", "F\n", "G\n"]

    {:ok, agent_pid} = Agent.start(fn -> [] end)

    {:ok, pid} =
      Tail.start_link(
        @path,
        fn output ->
          Agent.update(agent_pid, fn state -> state ++ output end)
        end,
        220
      )

    File.write(@path, Enum.at(output, 0), [:append])
    :timer.sleep(1000)
    assert Agent.get(agent_pid, & &1) == Enum.take(output, 1)

    File.write(@path, Enum.at(output, 1), [:append])
    :timer.sleep(1000)
    assert Agent.get(agent_pid, & &1) == Enum.take(output, 2)

    File.write(@path, Enum.at(output, 2), [:append])
    :timer.sleep(1000)
    assert Agent.get(agent_pid, & &1) == Enum.take(output, 3)

    effect.()

    File.write(@path, Enum.at(output, 3), [:append])
    File.write(@path, Enum.at(output, 4), [:append])
    :timer.sleep(1000)
    assert Agent.get(agent_pid, & &1) == Enum.take(output, 5)

    Tail.stop(pid)
  end
end
