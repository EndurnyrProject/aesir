defmodule Aesir.GameModeTestSupportTest do
  use ExUnit.Case, async: false

  @fixture Path.expand("../../fixtures/game_mode_selection_helper.exs", __DIR__)

  test "default selection runs shared and matching-mode cases while preserving exclusions" do
    for {mode, expected} <- [
          {"renewal", ["renewal", "shared"]},
          {"pre_renewal", ["pre_renewal", "shared"]}
        ] do
      {output, status} = run_fixture(mode)

      assert status == 0, output
      assert executed(output) == expected
    end
  end

  test "native integration includes select shared and matching cases with inherited overrides" do
    for {mode, selector, expected} <- [
          {"renewal", "integration_re:true", ["integration_renewal", "integration_shared"]},
          {"pre_renewal", "integration_pre_re:true",
           ["integration_pre_renewal", "integration_shared"]}
        ] do
      {output, status} = run_fixture(mode, [selector])

      assert status == 0, output
      assert executed(output) == expected
    end
  end

  defp run_fixture(mode, args \\ []) do
    System.cmd(
      System.find_executable("elixir"),
      ["--erl", "+S 2:2", "-pa", Application.app_dir(:commons, "ebin"), @fixture | args],
      env: [{"AESIR_DB_MODE", mode}],
      stderr_to_stdout: true
    )
  end

  defp executed(output) do
    ~r/^selection:(\w+)$/m
    |> Regex.scan(output, capture: :all_but_first)
    |> List.flatten()
    |> Enum.sort()
  end
end
