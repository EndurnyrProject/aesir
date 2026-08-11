defmodule Aesir.ZoneServer.Script.DslNpcskillTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @char_id 1_001
  @npc_gid 2_001

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

  test "casts Heal and broadcasts the NPC-sourced skill effect" do
    ctx = register_player()
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert Dsl.npcskill(ctx, :al_heal, 10, 99, 60) == ctx
    assert_receive {:combat, {:apply_heal, 1_145, @npc_gid}}

    assert_receive {:packet,
                    %SkillEffect{
                      skill_id: 28,
                      level: 10,
                      src_id: @npc_gid,
                      target_id: @char_id,
                      result: 1
                    }}
  end

  test "applies Increase AGI with the NPC as caster" do
    ctx = register_player()

    assert Dsl.npcskill(ctx, :al_incagi, 5, 99, 60) == ctx

    assert %{val1: 5, val2: 7, source_id: @npc_gid} =
             StatusStorage.get_status(:player, @char_id, :sc_increaseagi)
  end

  test "accepts string names and numeric ids" do
    ctx = register_player()
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    for skill <- ["AL_HEAL", 28] do
      assert Dsl.npcskill(ctx, skill, 10, 99, 60) == ctx
      assert_receive {:combat, {:apply_heal, 1_145, @npc_gid}}
    end
  end

  test "clamps stat point and NPC level" do
    ctx = register_player()
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert Dsl.npcskill(ctx, :al_heal, 10, 0, 0) == ctx
    assert_receive {:combat, {:apply_heal, 1, @npc_gid}}

    assert Dsl.npcskill(ctx, :al_heal, 10, 9_999, 9_999) == ctx
    assert_receive {:combat, {:apply_heal, 3_641, @npc_gid}}
  end

  test "warns and leaves the context unchanged for unknown and unsupported skills" do
    ctx = register_player()

    log =
      capture_log(fn ->
        assert Dsl.npcskill(ctx, :nonexistent_skill, 1, 99, 60) == ctx
        assert Dsl.npcskill(ctx, "NOT_A_SKILL", 1, 99, 60) == ctx
        assert Dsl.npcskill(ctx, :mg_firebolt, 1, 99, 60) == ctx
      end)

    assert log =~ "npcskill"
    refute_received {:packet, _}
  end

  test "halts detached contexts and warns when no NPC is attached" do
    ctx = register_player()
    detached = %{ctx | game_state: nil}
    no_npc = %{ctx | npc_gid: nil}

    assert Dsl.npcskill(detached, :al_heal, 10, 99, 60) == Ctx.halt(detached, :no_player)

    log = capture_log(fn -> assert Dsl.npcskill(no_npc, :al_heal, 10, 99, 60) == no_npc end)
    assert log =~ "npcskill"
  end

  defp setup_ets_tables(context), do: Aesir.TestEtsSetup.setup_ets_tables(context)

  defp register_player do
    player =
      %Character{
        id: @char_id,
        account_id: @char_id,
        name: "NpcSkillTarget",
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
      source: {:npc, __MODULE__},
      npc_gid: @npc_gid
    }
  end
end
