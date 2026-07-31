defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdEncoreTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot, as: Song
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BdEncore
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TestSupport.EnsembleSkill
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule UnitStub do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  @caster_id 1_000
  @instrument_id 90_305
  @encore_id 305
  @eligible_ids [317, 319, 320, 321, 322]

  Mimic.copy(Song)

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()

    stub(ItemManagement, :get_item_by_id, fn @instrument_id ->
      {:ok,
       %ItemDefinition{
         id: @instrument_id,
         aegis_name: "task21_instrument",
         name: "Task 21 Instrument",
         type: :weapon,
         subtype: :musical,
         weapon_level: 1
       }}
    end)

    :ok = UnitRegistry.register_unit(:player, @caster_id, UnitStub, %{}, self())
  end

  test "definition matches the pinned Encore table" do
    assert {:ok, BdEncore} = Catalog.active_module_for(:bd_encore)
    assert {:ok, definition} = Catalog.by_id(@encore_id)

    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.require_weapon == [:musical, :whip]
    assert definition.sp_cost == [1]
    assert definition.cast_time == [0]
    assert definition.fixed_cast_time == [0]
    assert definition.after_cast_delay == [300]
    assert definition.cooldown == [10_000]
  end

  test "only the four songs and Dissonance pass replay preflight" do
    for skill_id <- @eligible_ids do
      caster = player(%{skill_id: skill_id, level: 1})
      assert :ok = Interpreter.encore_replay_preflight(caster, caster.last_song, :self)
    end

    caster = player(%{skill_id: 304, level: 1}, %{304 => 1, @encore_id => 1})

    assert {:error, :skill_not_replayable} =
             Interpreter.encore_replay_preflight(caster, caster.last_song, :self)
  end

  test "no remembered song fails without commitment" do
    caster = player(nil)

    assert {:error, :no_song_to_replay} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert caster.stats.current_state.sp == 100
    assert caster.skill_cooldowns == %{}
    assert caster.act_delay_until == 0
  end

  test "replay requires the remembered level to remain learned" do
    caster = player(%{skill_id: 319, level: 3}, %{319 => 2, @encore_id => 1})

    assert {:error, :skill_not_learned} = Interpreter.cast(caster, @encore_id, 1, :self)
  end

  test "replay revalidates the current weapon" do
    caster = player(%{skill_id: 319, level: 1})
    caster = %{caster | stats: %{caster.stats | equipment: %Equipment{}}}

    assert {:error, :wrong_weapon} = Interpreter.cast(caster, @encore_id, 1, :self)
  end

  test "original and Encore cooldowns and the global act delay gate replay independently" do
    future = System.monotonic_time(:millisecond) + 10_000
    caster = player(%{skill_id: 319, level: 1})

    assert {:error, :on_cooldown} =
             Interpreter.cast(%{caster | skill_cooldowns: %{319 => future}}, @encore_id, 1, :self)

    assert {:error, :on_cooldown} =
             Interpreter.cast(
               %{caster | skill_cooldowns: %{@encore_id => future}},
               @encore_id,
               1,
               :self
             )

    assert {:error, :act_delayed} =
             Interpreter.cast(%{caster | act_delay_until: future}, @encore_id, 1, :self)
  end

  test "an encored song costs half its base with ordinary modifiers and Adaptation last" do
    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_adaptation, duration: 10_000)

    modifiers = %{
      {:skill_use_sp_rate, 317} => -20,
      {:skill_use_sp, 317} => 3,
      sp_cost_rate: 10
    }

    caster = player(%{skill_id: 317, level: 5}, nil, 100, modifiers)

    assert %Cost{sp_requirement: 14, sp: 14} =
             BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition())

    assert {:error, :insufficient_sp} =
             Interpreter.begin_cast(put_sp(caster, 13), @encore_id, 1, :self)

    assert {:casting, _caster, _info} =
             Interpreter.begin_cast(put_sp(caster, 14), @encore_id, 1, :self)
  end

  test "an encored ensemble receives no Adaptation discount" do
    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_adaptation, duration: 10_000)
    assert EnsembleSkill.definition().sp_cost == [50]
    caster = player(%{skill_id: EnsembleSkill.definition().id, level: 1})

    assert %Cost{sp_requirement: 25, sp: 25} =
             BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition())

    assert {:ok, replayed} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert replayed.stats.current_state.sp == 75
  end

  test "an encored ensemble costs half its base without Adaptation" do
    caster = player(%{skill_id: EnsembleSkill.definition().id, level: 1})

    assert {:ok, replayed} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert replayed.stats.current_state.sp == 75
  end

  test "zero transformed consumption still requires one SP for songs and ensembles" do
    modifiers = %{sp_cost_rate: -100}

    for skill_id <- [319, EnsembleSkill.definition().id] do
      caster = player(%{skill_id: skill_id, level: 1}, nil, 1, modifiers)

      assert %Cost{sp_requirement: 1, sp: 0} =
               BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition())

      assert {:error, :insufficient_sp} =
               Interpreter.begin_cast(put_sp(caster, 0), @encore_id, 1, :self)

      result = Interpreter.begin_cast(caster, @encore_id, 1, :self)
      assert elem(result, 0) in [:casting, :instant]
    end
  end

  test "all five remembered skills supply their own timing and keep one outer 300 ms delay" do
    for skill_id <- @eligible_ids do
      caster = player(%{skill_id: skill_id, level: 1})
      assert {:casting, ^caster, info} = Interpreter.begin_cast(caster, @encore_id, 1, :self)
      assert info.fixed == 300
      assert info.total > 300

      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert definition.after_cast_delay == List.duplicate(300, definition.max_level)
    end

    assert BdEncore.definition().after_cast_delay == [300]
  end

  test "successful replay runs one effect and commits transformed SP and both cooldowns" do
    caster = player(%{skill_id: 317, level: 5})

    expect(Combat, :execute_magic_splash, 1, fn _caster, {10, 20}, 4, _opts -> [] end)
    before = System.monotonic_time(:millisecond)

    assert {:ok, updated} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert updated.stats.current_state.sp == 77
    assert updated.skill_cooldowns[317] >= before + 5_000
    assert updated.skill_cooldowns[@encore_id] >= before + 10_000
    assert updated.act_delay_until >= before + 300
    assert updated.last_song == %{skill_id: 317, level: 5}
  end

  test "completion revalidates the original cooldown before effect or commitment" do
    caster = player(%{skill_id: 319, level: 1})
    assert {:casting, ^caster, _info} = Interpreter.begin_cast(caster, @encore_id, 1, :self)

    reject(&Song.snapshot/6)
    blocked = %{caster | skill_cooldowns: %{319 => System.monotonic_time(:millisecond) + 10_000}}

    assert {:error, :on_cooldown} = Interpreter.complete_cast(blocked, @encore_id, 1, :self)
    assert blocked.stats.current_state.sp == 100
    assert blocked.skill_cooldowns |> Map.keys() == [319]
    assert blocked.act_delay_until == 0
  end

  test "a failed remembered effect commits no SP, cooldown, or act delay" do
    caster = player(%{skill_id: 319, level: 1})

    expect(Song, :snapshot, fn ^caster, _definition, 1, :sc_whistle, _params, [] ->
      {:error, :failed}
    end)

    assert {:error, :failed} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert caster.stats.current_state.sp == 100
    assert caster.skill_cooldowns == %{}
    assert caster.act_delay_until == 0
  end

  defp player(memory, learned \\ nil, sp \\ 100, modifiers \\ %{}) do
    remembered = if is_map(memory), do: %{memory.skill_id => memory.level}, else: %{}
    learned = if is_nil(learned), do: Map.put(remembered, @encore_id, 1), else: learned

    %PlayerState{
      character_id: @caster_id,
      x: 10,
      y: 20,
      map_name: "prontera",
      last_song: memory,
      stats: %Stats{
        base_stats: %{dex: 1, int: 1},
        current_state: %{hp: 100, sp: sp},
        derived_stats: %{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{job_id: 19, job_level: 50, learned_skills: learned},
        equipment: %Equipment{right_hand: @instrument_id},
        modifiers: %{equipment: modifiers}
      }
    }
  end

  defp put_sp(caster, sp), do: put_in(caster.stats.current_state.sp, sp)
end
