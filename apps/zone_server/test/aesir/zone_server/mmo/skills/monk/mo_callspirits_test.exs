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

  @tag game_mode: :renewal
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

  test "a cast refuses to begin while the caster holds as many spheres as its level" do
    now = System.monotonic_time(:millisecond)
    {spheres, first} = SpiritSpheres.summon(SpiritSpheres.new(), now + 60_000, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, now + 120_000, 5)
    state = interpreter_state(50, spheres, 5)

    assert {:error, :spheres_full} = Interpreter.begin_cast(state, 261, 2, :self)
    assert {:error, :spheres_full} = Interpreter.cast(state, 261, 1, :self)

    {:ok, cast} = Interpreter.cast(state, 261, 3, :self)

    assert cast.stats.current_state.sp == 42
    assert [^first, ^second, _new] = SpiritSpheres.entries(cast.spirit_spheres)
  end

  test "the effect summons at the cast level whatever the progression" do
    {:ok, definition} = Catalog.by_id(261)
    learned = caster(50, SpiritSpheres.new(), 1)
    unlearned = put_in(learned.stats.progression.learned_skills, %{})
    missing = update_in(learned.stats, &Map.delete(&1, :progression))

    for state <- [unlearned, missing] do
      assert {:ok, updated} = MoCallspirits.cast(state, :self, 1, definition)
      assert SpiritSpheres.count(updated.spirit_spheres) == 1
    end
  end

  test "completion summons at the cast level after the learned level drops" do
    starting = interpreter_state(50, SpiritSpheres.new(), 5)

    assert {:casting, ^starting, _info} = Interpreter.begin_cast(starting, 261, 5, :self)

    downgraded = put_in(starting.stats.progression.learned_skills, %{261 => 1})

    assert {:ok, completed} = Interpreter.complete_cast(downgraded, 261, 5, :self)
    assert completed.stats.current_state.sp == 42
    assert SpiritSpheres.count(completed.spirit_spheres) == 1
  end

  test "the learned level does not cap the cast level" do
    state = interpreter_state(50, SpiritSpheres.new(), 6)

    assert {:casting, ^state, _info} = Interpreter.begin_cast(state, 261, 1, :self)
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
    |> Aesir.ZoneServer.PlayerStateFixture.build()
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

  @tag game_mode: :pre_renewal
  test "classic carries the source's data" do
    {:ok, definition} = Catalog.by_id(261)
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == []
  end
end
