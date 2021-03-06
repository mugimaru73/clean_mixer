defmodule Mix.Tasks.CleanMixer.FileCyclesTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "lists cycles in components dependencies" do
    output =
      capture_io(fn ->
        Mix.Task.run("clean_mixer.file_cycles")
      end)

    assert output =~
             "test/support/code_fixtures/old_doge.erl -> test/support/code_fixtures/doge_owner.ex"

    assert output =~
             "test/support/code_fixtures/doge_owner.ex -> test/support/code_fixtures/old_doge.erl"
  end
end
