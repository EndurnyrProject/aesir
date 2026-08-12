defmodule Aesir.ZoneServer.Script.DslSkilleffectTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @char_id 1_001

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    test_pid = self()

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(test_pid, {:packet, packet})
    end)

    :ok
  end

  test "broadcasts the self-sourced skill visual for a catalog name" do
    ctx = register_player()

    assert Dsl.skilleffect(ctx, :npc_selfdestruction, 1) == ctx

    assert_receive {:packet,
                    %SkillEffect{
                      skill_id: 173,
                      level: 1,
                      src_id: @char_id,
                      target_id: @char_id,
                      result: 1
                    }}
  end

  test "accepts a string skill name and a numeric id" do
    ctx = register_player()

    for skill <- ["NPC_SELFDESTRUCTION", 173] do
      assert Dsl.skilleffect(ctx, skill, 1) == ctx
      assert_receive {:packet, %SkillEffect{skill_id: 173, level: 1}}
    end
  end

  test "passes un-cataloged numeric ids through and forbids negative levels" do
    ctx = register_player()

    # skill 34 is not implemented server-side, but the client still animates it.
    assert Dsl.skilleffect(ctx, 34, -3) == ctx
    assert_receive {:packet, %SkillEffect{skill_id: 34, level: 0}}
  end

  test "warns and sends nothing for an unknown skill" do
    ctx = register_player()

    log =
      capture_log(fn ->
        assert Dsl.skilleffect(ctx, :nonexistent_skill, 1) == ctx
      end)

    assert log =~ "skilleffect"
    refute_received {:packet, _}
  end

  test "detached context is a silent no-op" do
    detached = %{register_player() | game_state: nil, char_id: nil}
    assert Dsl.skilleffect(detached, 173, 1) == detached
    refute_received {:packet, _}
  end

  test "errored context short-circuits" do
    ctx = Ctx.halt(register_player(), :boom)
    assert Dsl.skilleffect(ctx, 173, 1) == ctx
    refute_received {:packet, _}
  end

  defp setup_ets_tables(context), do: Aesir.TestEtsSetup.setup_ets_tables(context)

  defp register_player do
    player =
      %Character{
        id: @char_id,
        account_id: @char_id,
        name: "SkilleffectTarget",
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        class: 0,
        base_level: 1,
        job_level: 1,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1
      }
      |> PlayerState.new()

    :ok = UnitRegistry.register_unit(:player, @char_id, PlayerState, player, self())

    %Ctx{
      char_id: @char_id,
      account_id: @char_id,
      connection_pid: self(),
      game_state: player,
      source: {:npc, __MODULE__}
    }
  end
end
