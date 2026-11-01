defmodule Aesir.ZoneServer.Script.DslZenyAssignmentTest do
  use ExUnit.Case, async: true
  use Mimic

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(CharacterPersistence)

    stub(CharacterPersistence, :update_character, fn 7, fields, [async: true] ->
      send(self(), {:persisted, fields})
      {:ok, %Character{}}
    end)

    :ok
  end

  test "item-script balance assignments commit inline and allow balances above one billion" do
    ctx = context()

    result = Dsl.set_zeny(ctx, 1_000_000_001)

    assert result.game_state.zeny == 1_000_000_001
    assert result.session_state.game_state.zeny == 1_000_000_001
    assert Dsl.zeny(result) == 1_000_000_001
    assert_received {:persisted, %{zeny: 1_000_000_001}}

    assert_received {:send, :gameplay,
                     {:param_change, %ParamChange{var_id: 20, value: 1_000_000_001}}}
  end

  test "assignments use signed 32-bit parameter conversion, including wraparound" do
    for {value, expected} <- [
          {0, 0},
          {2_147_483_647, 2_147_483_647},
          {4_294_967_303, 7},
          {-4_294_967_289, 7}
        ] do
      result = Dsl.set_zeny(context(), value)
      assert result.game_state.zeny == expected
      assert_received {:persisted, %{zeny: ^expected}}
    end
  end

  test "a negative converted value ends the script without changing the balance" do
    for value <- [-1, 2_147_483_648, 4_294_967_295] do
      original = context()

      assert {:script_end, ended} = catch_throw(Dsl.set_zeny(original, value))
      assert ended.status == :ok
      assert ended.game_state == original.game_state
      assert ended.failures == [{:set_zeny, :negative_zeny}]
      refute_received {:persisted, _}
      refute_received {:send, :gameplay, {:param_change, _}}
    end
  end

  defp context do
    player = %PlayerState{character_id: 7, account_id: 8, zeny: 12}
    Ctx.from_session(%{game_state: player, connection_pid: self()}, {:item, 668})
  end
end
