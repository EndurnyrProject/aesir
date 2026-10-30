defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AcidTerrorAdditionalEffectGateTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAcidterror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  defp monster do
    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 0,
      spawn_area: %MobSpawn.SpawnArea{x: 0, y: 0}
    }

    MobState.new(2301, TestMob.definition(), spawn, "prontera", 0, 0)
  end

  setup :set_mimic_private

  setup do
    {:ok, definition} = Catalog.by_id(230)
    {:ok, definition: definition}
  end

  test "a target that does not survive receives no bleeding or armor-break rolls", %{
    definition: definition
  } do
    reject(&TargetResolver.resolve/1)
    reject(&StatusInterpreter.apply_status/4)
    reject(&EquipBreak.resolve_slot/4)

    for caster <- [%PlayerState{stats: %Stats{}}, monster()],
        hit? <- [true, false] do
      stub(Combat, :execute_acid_terror_attack, fn ^caster, 2302, _opts ->
        {:ok, %{hit?: hit?, blocked?: not hit?, target_survives?: false}}
      end)

      assert {:ok, ^caster} = AmAcidterror.cast(caster, {:unit, 2302}, 5, definition)
    end
  end

  test "a monster's connected hit can bleed and break a surviving player's armor", %{
    definition: definition
  } do
    caster = monster()

    stub(Combat, :execute_acid_terror_attack, fn ^caster, 2302, _opts ->
      {:ok, %{hit?: true, blocked?: false, target_survives?: true}}
    end)

    stub(TargetResolver, :resolve, fn 2302 ->
      {:ok, self(), %PlayerState{stats: %Stats{}}, :player}
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 2302, :sc_bleeding, opts ->
      assert opts[:caster_id] == 2301
      assert opts[:success_rate] == 15
      :ok
    end)

    expect(EquipBreak, :resolve_slot, fn _rate, {:player, 2302, _stats}, :armor, [] -> [] end)

    assert {:ok, ^caster} = AmAcidterror.cast(caster, {:unit, 2302}, 5, definition)
  end

  test "a monster's blocked hit and any caster's miss apply no additional effects", %{
    definition: definition
  } do
    reject(&TargetResolver.resolve/1)
    reject(&StatusInterpreter.apply_status/4)
    reject(&EquipBreak.resolve_slot/4)

    for {caster, blocked?} <- [
          {monster(), true},
          {monster(), false},
          {%PlayerState{stats: %Stats{}}, false}
        ] do
      stub(Combat, :execute_acid_terror_attack, fn ^caster, 2302, _opts ->
        {:ok, %{hit?: false, blocked?: blocked?, target_survives?: true}}
      end)

      assert {:ok, ^caster} = AmAcidterror.cast(caster, {:unit, 2302}, 5, definition)
    end
  end
end
