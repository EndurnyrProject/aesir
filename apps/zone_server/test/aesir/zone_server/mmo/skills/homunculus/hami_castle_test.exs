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
end
