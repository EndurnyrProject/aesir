defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdAdaptationTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BdAdaptation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adaptation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  setup :verify_on_exit!

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned instant timing and cooldown" do
    assert {:ok, BdAdaptation} = Catalog.active_module_for(:bd_adaptation)
    assert {:ok, definition} = Catalog.by_id(304)

    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.sp_cost == [10]
    assert definition.cast_time == [0]
    assert definition.fixed_cast_time == [0]
    assert definition.after_cast_delay == [300]
    assert definition.cooldown == [300_000]
  end

  test "status is a finite registered self buff" do
    assert Adaptation in Effects.all()
    assert :sc_adaptation = Adaptation.id()
    assert %{duration: 300_000} = Registry.get_definition(:sc_adaptation)

    assert %{
             permanent: false,
             properties: [:buff],
             icon: :adaptation
           } = Adaptation.metadata()
  end

  test "ordinary active cast requires 10 SP, consumes none, applies 300 seconds, and arms cooldown" do
    expect(StatusInterpreter, :apply_status, fn :player, 1_000, :sc_adaptation, params ->
      assert params[:caster_id] == 1_000
      assert params[:duration] == 300_000
      assert params[:owner_refresh] == :defer
      :ok
    end)

    before = System.monotonic_time(:millisecond)
    assert {:ok, updated} = Interpreter.cast(game_state(10), 304, 1, :self)
    assert updated.stats.current_state.sp == 10
    assert updated.skill_cooldowns[304] >= before + 300_000
    assert updated.act_delay_until >= before + 300
  end

  test "less than 10 SP fails before status application or cooldown" do
    reject(&StatusInterpreter.apply_status/4)

    state = game_state(9)
    assert {:error, :insufficient_sp} = Interpreter.cast(state, 304, 1, :self)
    assert state.skill_cooldowns == %{}
  end

  defp game_state(sp) do
    %{
      character_id: 1_000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{hp: 100, sp: sp},
        derived_stats: %{max_hp: 100, max_sp: 100},
        progression: %{learned_skills: %{304 => 1}}
      }
    }
  end
end
