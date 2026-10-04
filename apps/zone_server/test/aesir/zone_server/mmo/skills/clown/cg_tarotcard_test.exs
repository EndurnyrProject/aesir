defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgTarotcardTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgTarotcard
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Tarot
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    %{
      caster: PlayerStateFixture.build(%{character_id: 17, stats: %{}}),
      definition: CgTarotcard.definition()
    }
  end

  test "the cast requires the listed SP but spends none up front", %{
    caster: caster,
    definition: definition
  } do
    assert %{sp: 0, sp_requirement: 40} =
             CgTarotcard.dynamic_cost(caster, {:unit, 18}, 5, definition)
  end

  test "a played card spends 40 SP from the returned caster", %{
    caster: caster,
    definition: definition
  } do
    stub(Combat, :resolve_combatant, fn 42 -> {:ok, %{unit_type: :mob, unit_id: 42}} end)
    expect(Tarot, :play, fn ^caster, {:mob, 42}, 5 -> {:ok, :tower} end)

    assert {:ok, %{stats: %{current_state: %{sp: 60}}}} =
             CgTarotcard.cast(caster, {:unit, 42}, 5, definition)
  end

  test "a failed card returns the caster unchanged", %{caster: caster, definition: definition} do
    expect(Tarot, :play, fn ^caster, {:player, 18}, 5 -> {:error, :failed} end)
    assert {:ok, ^caster} = CgTarotcard.cast(caster, {:unit, {:player, 18}}, 5, definition)
  end

  test "mob casting plays a card on the typed target", %{definition: definition} do
    {:ok, mob_definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }

    caster = MobState.new(19, mob_definition, spawn, "prontera", 100, 100)
    expect(Tarot, :play, fn ^caster, {:player, 18}, 3 -> {:ok, :star} end)

    assert :ok = CgTarotcard.mob_cast(caster, {:unit, :player, 18}, 3, definition, %{})
  end
end
