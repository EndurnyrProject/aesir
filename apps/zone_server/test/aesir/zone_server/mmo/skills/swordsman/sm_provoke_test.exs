defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvokeTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry, as: StatusRegistry
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(EquipComa)
    :ok
  end

  test "cast/4 applies SC_PROVOKE to mob with val2=2+3*level, val3=5+5*level" do
    {:ok, definition} = Catalog.by_id(6)
    caster = caster_at_level(99)
    mob_id = 500
    level = 3
    duration = Enum.at(definition.duration, level - 1)

    expect(TargetResolver, :resolve, fn ^mob_id ->
      {:ok, self(), mob_at_level(mob_id, 1), :mob}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob,
                                                ^mob_id,
                                                :sc_provoke,
                                                [
                                                  val1: ^level,
                                                  val2: 11,
                                                  val3: 20,
                                                  caster_id: 1,
                                                  duration: ^duration
                                                ] ->
      :ok
    end)

    # A caster without a coma bonus never reaches the coma roll.
    reject(&EquipComa.trigger?/2)
    reject(&MobSession.apply_coma/3)

    assert {:ok, ^caster} = SmProvoke.cast(caster, {:unit, mob_id}, level, definition)
  end

  test "a landed taunt rolls the player caster's coma bonuses and zaps the victim passively" do
    {:ok, definition} = Catalog.by_id(6)
    caster = caster_at_level(99)
    mob_id = 500

    stub(TargetResolver, :resolve, fn ^mob_id -> {:ok, self(), mob_at_level(mob_id, 1), :mob} end)
    expect(StatusInterpreter, :apply_status, fn :mob, ^mob_id, :sc_provoke, _params -> :ok end)
    stub(EquipComa, :bonus?, fn %{unit_id: 1} -> true end)
    expect(EquipComa, :trigger?, fn %{unit_id: 1}, %{unit_id: ^mob_id} -> true end)

    expect(MobSession, :apply_coma, fn pid, {:player, 1}, %{passive?: true} when pid == self() ->
      :ok
    end)

    assert {:ok, ^caster} = SmProvoke.cast(caster, {:unit, mob_id}, 1, definition)
  end

  test "classic re-arms a one second cooldown that renewal dropped" do
    assert SmProvoke.definition(:renewal).cooldown == []
    assert SmProvoke.definition(:pre_renewal).cooldown == List.duplicate(1_000, 10)
  end

  test "refuses undead and status-immune targets in both modes" do
    immunity = StatusRegistry.get_definition(:sc_provoke).immunity

    assert :undead in immunity
    assert :boss in immunity
  end

  test "always lands when the caster far outlevels the target" do
    {:ok, definition} = Catalog.by_id(6)
    caster = caster_at_level(99)
    mob_id = 500

    stub(TargetResolver, :resolve, fn ^mob_id -> {:ok, self(), mob_at_level(mob_id, 1), :mob} end)
    expect(StatusInterpreter, :apply_status, fn :mob, ^mob_id, :sc_provoke, _params -> :ok end)
    reject(&EquipComa.trigger?/2)

    assert {:ok, ^caster} = SmProvoke.cast(caster, {:unit, mob_id}, 1, definition)
  end

  test "never lands when the target far outlevels the caster, and still completes the cast" do
    {:ok, definition} = Catalog.by_id(6)
    caster = caster_at_level(1)
    mob_id = 500

    stub(TargetResolver, :resolve, fn ^mob_id ->
      {:ok, self(), mob_at_level(mob_id, 200), :mob}
    end)

    reject(&StatusInterpreter.apply_status/4)
    reject(&EquipComa.trigger?/2)

    assert {:ok, ^caster} = SmProvoke.cast(caster, {:unit, mob_id}, 1, definition)
  end

  test "skips the roll rather than losing the taunt when a level cannot be read" do
    {:ok, definition} = Catalog.by_id(6)
    caster = struct(MobState, instance_id: 2)
    mob_id = 500

    stub(TargetResolver, :resolve, fn ^mob_id ->
      {:ok, self(), struct(MobState, instance_id: mob_id), :mob}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, ^mob_id, :sc_provoke, _params -> :ok end)

    assert {:ok, ^caster} = SmProvoke.cast(caster, {:unit, mob_id}, 1, definition)
  end

  defp caster_at_level(level),
    do: TrapTestHelper.player(1, %{stats: %{progression: %{base_level: level}}})

  defp mob_at_level(mob_id, level), do: TrapTestHelper.mob(mob_id, level: level)
end
