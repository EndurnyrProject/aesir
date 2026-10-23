defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiCastleTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiCastle
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @owner_id 80_051
  @gid 80_052

  setup :setup_ets_tables

  defp caster do
    %HomunculusState{
      id: 1,
      world_gid: @gid,
      owner_character_id: @owner_id,
      class_id: 6_003,
      name: "Amistr"
    }
  end

  defp register_owner(owner) do
    :ok = UnitRegistry.register_unit(:player, @owner_id, PlayerState, owner, self())
  end

  test "a dead owner swaps nothing once the cast is paid" do
    register_owner(%PlayerState{character_id: @owner_id, action_state: :dead})
    caster = caster()

    assert {:ok, ^caster} = HamiCastle.cast(caster, :self, 5, HamiCastle.definition())
  end

  test "a living owner swaps at rank five" do
    register_owner(%PlayerState{
      character_id: @owner_id,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    })

    caster = caster()

    assert {:local_effects, ^caster, [{:homunculus, {:castling_swap, @gid}}]} =
             HamiCastle.cast(caster, :self, 5, HamiCastle.definition())
  end

  # homunculus_castling.cpp:35-36: a missed roll tells the master with the bare
  # clif_skill_fail.
  test "a missed roll tells the owner the skill failed" do
    register_owner(%PlayerState{
      character_id: @owner_id,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    })

    caster = caster()
    :rand.seed(:exsss, {1, 2, 3})
    results = for _ <- 1..50, do: HamiCastle.cast(caster, :self, 1, HamiCastle.definition())
    failed = {:local_effects, caster, [{:player, {:skill_failed, 8_005}}]}
    swapped = {:local_effects, caster, [{:homunculus, {:castling_swap, @gid}}]}

    assert failed in results
    assert Enum.all?(results, &(&1 in [failed, swapped]))
  end

  test "Castling refuses an owner on another map before the endpoint checks" do
    register_owner(%PlayerState{character_id: @owner_id, map_name: "other_map", x: 1, y: 1})
    caster = %{caster() | map_name: "castle_map", x: 1, y: 1}

    assert {:error, :different_map} =
             HamiCastle.validate(caster, :self, 1, HamiCastle.definition())
  end
end
