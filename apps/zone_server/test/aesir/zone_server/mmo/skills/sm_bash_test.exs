defmodule Aesir.ZoneServer.Mmo.Skills.SmBashTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.SmBash
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000

  # Chance to stun is (bash_level - 5) * base_level * 10, out of 10_000.
  # base_level 1000 at bash level 6 yields 10_000 => a guaranteed roll.
  # base_level 0 yields 0 => the roll can never succeed.
  defp build_caster(learned_skills, base_level \\ 1000) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{
        base_level: base_level,
        job_level: 30,
        learned_skills: learned_skills
      },
      equipment: %Equipment{weapon: WeaponTypes.get_weapon_id(:one_handed_sword), shield: 0}
    }

    %PlayerState{character_id: 1000, stats: stats}
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:sm_bash)
    definition
  end

  test "Catalog.active_module_for/1 resolves sm_bash" do
    assert {:ok, SmBash} = Catalog.active_module_for(:sm_bash)
  end

  test "cast/4 hits the target for 100% + 30% per level, without crit" do
    caster = build_caster(%{})

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 7
      assert opts[:skill_ratio] == 100 + 30 * 7
      assert opts[:skip_crit] == true
      :ok
    end)

    assert {:ok, ^caster} = SmBash.cast(caster, {:unit, @target_id}, 7, definition())
  end

  test "cast/4 returns {:ok, caster} and does not apply stun when SM_FATALBLOW is not learned" do
    caster = build_caster(%{})

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = SmBash.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "cast/4 never applies stun at level 5 even with SM_FATALBLOW learned" do
    caster = build_caster(%{145 => 1})

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = SmBash.cast(caster, {:unit, @target_id}, 5, definition())
  end

  test "cast/4 applies sc_stun to a mob target at level 6 with SM_FATALBLOW when the roll succeeds" do
    caster = build_caster(%{145 => 1})

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, params ->
      assert params[:duration] == 4_500
      :ok
    end)

    assert {:ok, ^caster} = SmBash.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "cast/4 applies stun to a player target when the mob lookup misses" do
    caster = build_caster(%{145 => 1})

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> false end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_stun, _params ->
      :ok
    end)

    assert {:ok, ^caster} = SmBash.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "cast/4 does not apply stun when the chance roll cannot succeed" do
    caster = build_caster(%{145 => 1}, 0)

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = SmBash.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "cast/4 propagates an attack error without applying riders" do
    caster = build_caster(%{145 => 1})

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :target_out_of_range} =
             SmBash.cast(caster, {:unit, @target_id}, 6, definition())
  end
end
