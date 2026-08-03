defmodule Aesir.ZoneServer.Script.DslHomunculusTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "homevolution stages evolution without changing player state" do
    ctx = ctx()

    assert %Ctx{homunculus_effects: [:homunculus_evolution], game_state: game_state} =
             Dsl.homevolution(ctx)

    assert game_state == ctx.game_state
  end

  test "add_homunculus_intimacy stages positive hundredths in order" do
    ctx = ctx()

    assert %Ctx{
             homunculus_effects: [
               :homunculus_evolution,
               {:homunculus_intimacy, 100}
             ]
           } =
             ctx
             |> Dsl.homevolution()
             |> Dsl.add_homunculus_intimacy(100)
  end

  test "staging short-circuits halted contexts and rejects invalid amounts" do
    halted = Ctx.halt(ctx(), :stopped)

    assert Dsl.homevolution(halted) == halted
    assert Dsl.add_homunculus_intimacy(halted, 100) == halted

    assert_raise FunctionClauseError, fn ->
      Dsl.add_homunculus_intimacy(ctx(), 0)
    end
  end

  defp ctx do
    %Ctx{
      char_id: 1,
      account_id: 2,
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1, account_id: 2},
      source: {:item, 12_040}
    }
  end
end
