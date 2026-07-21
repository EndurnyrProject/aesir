defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoCallspiritsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoCallspirits
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  test "successful cast adds one independently timed sphere up to learned level" do
    {:ok, definition} = Catalog.by_id(261)
    caster = caster(50, SpiritSpheres.new(), 2)

    assert {:ok, updated} = MoCallspirits.cast(caster, :self, 2, definition)
    assert caster.stats.current_state.sp == updated.stats.current_state.sp
    assert [entry] = SpiritSpheres.entries(updated.spirit_spheres)
    assert entry.expires_at > System.monotonic_time(:millisecond) + 599_000
    assert SpiritSpheres.next_expiry(updated.spirit_spheres) == entry.expires_at
  end

  test "definition preserves Renewal resource and timing metadata" do
    {:ok, definition} = Catalog.by_id(261)

    assert definition.sp_cost == [8, 8, 8, 8, 8]
    assert definition.cast_time == [500, 500, 500, 500, 500]
    assert definition.fixed_cast_time == [500, 500, 500, 500, 500]
    assert definition.after_cast_delay == []
  end

  test "casting at cap replaces the oldest sphere" do
    {:ok, definition} = Catalog.by_id(261)
    now = System.monotonic_time(:millisecond)
    {spheres, first} = SpiritSpheres.summon(SpiritSpheres.new(), now + 60_000, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, now + 120_000, 5)

    assert {:ok, updated} =
             MoCallspirits.cast(caster(50, spheres, 2), :self, 1, definition)

    second_id = second.id
    assert [%{id: ^second_id}, %{id: new_id}] = SpiritSpheres.entries(updated.spirit_spheres)
    assert new_id > second.id
    refute first.id in Enum.map(SpiritSpheres.entries(updated.spirit_spheres), & &1.id)
  end

  test "interpreter completion charges SP only after sphere creation succeeds" do
    {:ok, state} =
      Interpreter.cast(interpreter_state(50, SpiritSpheres.new()), 261, 1, :self)

    assert state.stats.current_state.sp == 42
    assert SpiritSpheres.count(state.spirit_spheres) == 1
  end

  test "requested cast level does not lower the learned sphere cap" do
    now = System.monotonic_time(:millisecond)
    {spheres, first} = SpiritSpheres.summon(SpiritSpheres.new(), now + 60_000, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, now + 120_000, 5)

    {:ok, state} = Interpreter.cast(interpreter_state(50, spheres, 5), 261, 1, :self)

    assert [^first, ^second, _new] = SpiritSpheres.entries(state.spirit_spheres)
  end

  test "missing or unlearned progression rejects the sphere effect" do
    {:ok, definition} = Catalog.by_id(261)
    learned = caster(50, SpiritSpheres.new(), 1)
    unlearned = put_in(learned.stats.progression.learned_skills, %{})
    missing = update_in(learned.stats, &Map.delete(&1, :progression))

    for state <- [unlearned, missing] do
      assert {:error, :skill_not_learned} =
               MoCallspirits.cast(state, :self, 1, definition)

      assert SpiritSpheres.count(state.spirit_spheres) == 0
    end
  end

  test "completion rejects a requested level above the current learned level" do
    timer = make_ref()

    starting =
      interpreter_state(50, SpiritSpheres.new(), 5)
      |> Map.merge(%{
        spirit_sphere_revision: 7,
        spirit_sphere_timer_generation: 4,
        spirit_sphere_timer: timer
      })

    assert {:casting, ^starting, _info} = Interpreter.begin_cast(starting, 261, 5, :self)

    downgraded = put_in(starting.stats.progression.learned_skills, %{261 => 1})

    assert {:error, :skill_not_learned} =
             Interpreter.complete_cast(downgraded, 261, 5, :self)

    assert downgraded.stats.current_state.sp == 50
    assert SpiritSpheres.count(downgraded.spirit_spheres) == 0
    assert downgraded.spirit_sphere_revision == 7
    assert downgraded.spirit_sphere_timer_generation == 4
    assert downgraded.spirit_sphere_timer == timer
  end

  test "learned levels above the definition maximum are rejected" do
    state = interpreter_state(50, SpiritSpheres.new(), 6)

    assert {:error, :skill_not_learned} = Interpreter.begin_cast(state, 261, 1, :self)
    assert state.stats.current_state.sp == 50
    assert SpiritSpheres.count(state.spirit_spheres) == 0
  end

  defp interpreter_state(sp, spirit_spheres, learned_level \\ 1) do
    %{
      character_id: 4000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      spirit_spheres: spirit_spheres,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{hp: 100, sp: sp},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: %{261 => learned_level}},
        equipment: %{}
      }
    }
  end

  defp caster(sp, spirit_spheres, learned_level) do
    %{
      character_id: 4000,
      spirit_spheres: spirit_spheres,
      stats: %{
        current_state: %{hp: 100, sp: sp},
        progression: %{learned_skills: %{261 => learned_level}}
      }
    }
  end
end
