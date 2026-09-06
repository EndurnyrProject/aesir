defmodule Aesir.ZoneServer.IntegrationModeSelectionTest do
  use ExUnit.Case, async: false

  @root Path.expand("../../../../..", __DIR__)
  @fixture "apps/zone_server/test/fixtures/integration_mode_selection_helper.exs"

  @tag timeout: 120_000
  test "integration alias selects the boot mode and includes shared integrations" do
    for {mode, expected} <- [
          {nil, ["renewal", "shared"]},
          {"renewal", ["renewal", "shared"]},
          {"pre_renewal", ["pre_renewal", "shared"]}
        ] do
      {output, status} =
        System.cmd(
          System.find_executable("mix"),
          ["test.integration", @fixture, "--no-compile", "--seed", "0"],
          cd: @root,
          env: [{"AESIR_DB_MODE", mode}, {"ERL_FLAGS", "+S 2:2"}],
          stderr_to_stdout: true
        )

      assert status == 0, output

      executed =
        ~r/^selection:(\w+)$/m
        |> Regex.scan(output, capture: :all_but_first)
        |> List.flatten()
        |> Enum.sort()

      assert executed == expected
    end
  end
end
