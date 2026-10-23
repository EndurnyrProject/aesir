defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdEncoreTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Performance
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot, as: Song
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BdEncore
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TestSupport.EnsembleSkill
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
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
    if GameMode.mode() == :pre_renewal do
      stub(Performance, :perform, fn caster, definition, level, _status, _params, _opts ->
        {:ok, Song.remember(caster, definition.id, level)}
      end)
    end

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

  @tag game_mode: :renewal
  test "definition matches the pinned Encore table" do
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

  test "Encore completes its own instant attempt before the remembered skill begins" do
    caster = player(%{skill_id: 319, level: 1})
    before = System.monotonic_time(:millisecond)

    assert {:instant, finished} = Interpreter.begin_cast(caster, @encore_id, 1, :self)
    assert finished.stats.current_state.sp == 100

    if GameMode.mode() == :renewal,
      do: assert(finished.skill_cooldowns[@encore_id] >= before + 10_000),
      else: assert(finished.skill_cooldowns == %{})

    case Interpreter.begin_encore_replay(finished, finished.last_song, :self) do
      {:casting, ^finished, info} -> assert info.skill_id == 319
      {:instant, replayed} -> assert replayed.stats.current_state.sp < 100
    end
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

  test "the remembered level stays castable while any rank remains learned" do
    caster = player(%{skill_id: 319, level: 3}, %{319 => 2, @encore_id => 1})

    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)

    case Interpreter.begin_encore_replay(encore, encore.last_song, :self) do
      {:casting, ^encore, %{skill_id: 319, level: 3}} -> :ok
      {:instant, replayed} -> assert replayed.character_id == caster.character_id
    end
  end

  test "replay revalidates the current weapon" do
    caster = player(%{skill_id: 319, level: 1})
    caster = %{caster | stats: %{caster.stats | equipment: %Equipment{}}}

    assert {:error, :wrong_weapon} = Interpreter.cast(caster, @encore_id, 1, :self)
  end

  test "the original cooldown gates only the second attempt, while Encore has its own gate" do
    future = System.monotonic_time(:millisecond) + 10_000
    caster = player(%{skill_id: 319, level: 1})

    assert {:ok, encore} =
             Interpreter.cast(%{caster | skill_cooldowns: %{319 => future}}, @encore_id, 1, :self)

    assert {:error, :on_cooldown} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    assert {:error, {:not_ok, :silent}} =
             Interpreter.cast(
               %{caster | skill_cooldowns: %{@encore_id => future}},
               @encore_id,
               1,
               :self
             )

    assert {:error, :act_delayed} =
             Interpreter.cast(%{caster | act_delay_until: future}, @encore_id, 1, :self)
  end

  @tag game_mode: :renewal
  test "an encored song costs half its base with ordinary modifiers and Adaptation last" do
    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_adaptation, duration: 10_000)

    modifiers = %{
      {:skill_use_sp_rate, 317} => 20,
      {:skill_use_sp, 317} => 3,
      sp_cost_rate: 10
    }

    caster = player(%{skill_id: 317, level: 5}, nil, 100, modifiers)

    assert %Cost{sp_requirement: 1, sp: 0} =
             BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition())

    assert {:instant, encore} = Interpreter.begin_cast(put_sp(caster, 13), @encore_id, 1, :self)

    assert {:error, :insufficient_sp} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    assert {:instant, encore} = Interpreter.begin_cast(put_sp(caster, 14), @encore_id, 1, :self)

    assert {:casting, _caster, _info} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)
  end

  test "an encored ensemble receives no Adaptation discount" do
    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_adaptation, duration: 10_000)
    assert EnsembleSkill.definition().sp_cost == [50]

    caster =
      player(%{skill_id: EnsembleSkill.definition().id, level: 1}) |> with_ensemble_partner()

    assert %Cost{sp_requirement: 1, sp: 0} =
             BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition())

    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert encore.stats.current_state.sp == 100
    assert {:ok, replayed} = Interpreter.complete_encore_replay(encore, encore.last_song, :self)
    assert replayed.stats.current_state.sp == 75
  end

  test "an encored ensemble costs half its base without Adaptation" do
    caster =
      player(%{skill_id: EnsembleSkill.definition().id, level: 1}) |> with_ensemble_partner()

    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert encore.stats.current_state.sp == 100
    assert {:ok, replayed} = Interpreter.complete_encore_replay(encore, encore.last_song, :self)
    assert replayed.stats.current_state.sp == 75
  end

  test "an encored ensemble needs an adjacent partner when its replay begins" do
    caster = player(%{skill_id: EnsembleSkill.definition().id, level: 1})
    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)

    assert {:error, :ensemble_partner_required} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)
  end

  @tag game_mode: :pre_renewal
  test "an encored ensemble's replay records the partner found when it begins" do
    caster =
      player(%{skill_id: EnsembleSkill.definition().id, level: 1}) |> with_ensemble_partner()

    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)

    assert {:instant, replayed} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    assert replayed.ensemble_partner == @caster_id + 1
  end

  test "zero transformed consumption still requires one SP for songs and ensembles" do
    modifiers = %{sp_cost_rate: -100}

    for skill_id <- [319, EnsembleSkill.definition().id] do
      caster = player(%{skill_id: skill_id, level: 1}, nil, 1, modifiers)

      caster =
        if skill_id == EnsembleSkill.definition().id,
          do: with_ensemble_partner(caster),
          else: caster

      assert %Cost{sp_requirement: 1, sp: 0} =
               BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition())

      assert {:error, :insufficient_sp} =
               Interpreter.begin_cast(put_sp(caster, 0), @encore_id, 1, :self)

      assert {:instant, finished} = Interpreter.begin_cast(caster, @encore_id, 1, :self)
      assert finished.stats.current_state.sp == 1
    end
  end

  @tag game_mode: :renewal
  test "all five remembered skills begin a separate cast after instant Encore" do
    for skill_id <- @eligible_ids do
      caster = player(%{skill_id: skill_id, level: 1})
      before = System.monotonic_time(:millisecond)
      assert {:instant, encore} = Interpreter.begin_cast(caster, @encore_id, 1, :self)
      assert encore.act_delay_until >= before + 300

      assert {:casting, ^encore, info} =
               Interpreter.begin_encore_replay(encore, encore.last_song, :self)

      assert info.skill_id == skill_id
      assert info.origin == :encore
      assert info.fixed == 300
      assert info.total > info.fixed
    end

    assert BdEncore.definition().after_cast_delay == [300]
  end

  @tag game_mode: :renewal
  test "successful remembered attempt runs once and commits its cost and both cooldowns" do
    caster = player(%{skill_id: 317, level: 5})

    expect(Combat, :execute_magic_splash, 1, fn _caster, {10, 20}, 4, _opts -> [] end)
    before = System.monotonic_time(:millisecond)

    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert encore.stats.current_state.sp == 100
    assert {:ok, updated} = Interpreter.complete_encore_replay(encore, encore.last_song, :self)
    assert updated.stats.current_state.sp == 77
    assert updated.skill_cooldowns[317] >= before + 5_000
    assert updated.skill_cooldowns[@encore_id] >= before + 10_000
    assert updated.act_delay_until >= before + 300
    assert updated.last_song == %{skill_id: 317, level: 5}
  end

  @tag game_mode: :renewal
  test "remembered completion revalidates its own cooldown without spending SP" do
    caster = player(%{skill_id: 319, level: 1})
    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)

    assert {:casting, ^encore, _info} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    reject(&Song.snapshot/6)

    blocked =
      put_in(encore.skill_cooldowns[319], System.monotonic_time(:millisecond) + 10_000)

    assert {:error, :on_cooldown} =
             Interpreter.complete_encore_replay(blocked, blocked.last_song, :self)

    assert blocked.stats.current_state.sp == 100
    assert Map.has_key?(blocked.skill_cooldowns, @encore_id)
  end

  @tag game_mode: :renewal
  test "a failed remembered effect keeps Encore's committed pacing but spends no replay SP" do
    caster = player(%{skill_id: 319, level: 1})
    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)

    expect(Song, :snapshot, fn performer, _definition, 1, :sc_whistle, _params, [] ->
      assert performer.character_id == caster.character_id
      {:error, :failed}
    end)

    assert {:error, :failed} =
             Interpreter.complete_encore_replay(encore, encore.last_song, :self)

    assert encore.stats.current_state.sp == 100
    assert Map.has_key?(encore.skill_cooldowns, @encore_id)
    refute Map.has_key?(encore.skill_cooldowns, 319)
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
        modifiers: %Modifiers{equipment: modifiers}
      }
    }
  end

  defp with_ensemble_partner(caster) do
    if GameMode.mode() == :pre_renewal do
      {:ok, dancer_job_id} = AvailableJobs.job_name_to_id(:dancer)
      partner = player(%{skill_id: EnsembleSkill.definition().id, level: 1})
      partner = put_in(partner.stats.progression.job_id, dancer_job_id)

      partner = %{
        partner
        | character_id: @caster_id + 1,
          action_state: :idle,
          party_id: 1,
          x: caster.x + 1
      }

      :ok =
        UnitRegistry.register_unit(:player, partner.character_id, PlayerState, partner, self())

      :ok = SpatialIndex.add_player(partner.character_id, partner.x, partner.y, partner.map_name)
      %{caster | party_id: 1}
    else
      caster
    end
  end

  defp put_sp(caster, sp), do: put_in(caster.stats.current_state.sp, sp)

  @tag game_mode: :pre_renewal
  test "the performing lock refuses Encore but permits strike and Adaptation" do
    :ok =
      StatusStorage.apply_status(:player, @caster_id, :sc_dancing,
        val1: 319,
        val2: 77,
        state: %{upkeep: 5, ticks: 0}
      )

    refute StatusInterpreter.can_use_skill?(:player, @caster_id, @encore_id)
    assert StatusInterpreter.can_use_skill?(:player, @caster_id, 316)
    assert StatusInterpreter.can_use_skill?(:player, @caster_id, 304)
  end

  @tag game_mode: :pre_renewal
  test "Encore replays Whistle as a field for half its classic SP cost" do
    caster = player(%{skill_id: 319, level: 5})
    assert BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition()).sp == 0

    expect(Performance, :perform, fn performer, definition, 5, :sc_whistle, params, opts ->
      assert performer.character_id == caster.character_id
      assert definition.id == 319
      assert params[:val2] > 0
      assert opts[:kind] == :song
      assert opts[:upkeep] == 5
      {:ok, Song.remember(performer, 319, 5)}
    end)

    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert encore.stats.current_state.sp == 100

    assert {:instant, updated} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    assert updated.stats.current_state.sp == 80
    assert updated.last_song == %{skill_id: 319, level: 5}
    assert updated.skill_cooldowns == %{}
  end

  @tag game_mode: :pre_renewal
  test "classic carries the source's instant cast and SP" do
    {:ok, definition} = Catalog.by_id(305)
    assert definition.sp_cost == [1]
    assert definition.cast_time == [0]
    assert definition.fixed_cast_time == [0]
    assert definition.after_cast_delay == []
    assert definition.cooldown == []
  end

  @tag game_mode: :pre_renewal
  test "classic encored song costs half its base with ordinary modifiers and no Adaptation discount" do
    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_adaptation, duration: 10_000)

    modifiers = %{
      {:skill_use_sp_rate, 317} => 20,
      {:skill_use_sp, 317} => 3,
      sp_cost_rate: 10
    }

    caster = player(%{skill_id: 317, level: 5}, nil, 100, modifiers)

    assert %Cost{sp_requirement: 1, sp: 0} =
             BdEncore.dynamic_cost(caster, :self, 1, BdEncore.definition())

    assert {:instant, encore} = Interpreter.begin_cast(put_sp(caster, 9), @encore_id, 1, :self)

    assert {:error, :insufficient_sp} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    stub(Combat, :execute_magic_splash, fn _caster, _center, _radius, _opts -> [] end)

    assert {:instant, encore} = Interpreter.begin_cast(put_sp(caster, 10), @encore_id, 1, :self)

    assert {:instant, replayed} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    assert replayed.stats.current_state.sp == 0
  end

  @tag game_mode: :pre_renewal
  test "classic remembered skills replay instantly with no delay" do
    stub(Combat, :execute_magic_splash, fn _caster, _center, _radius, _opts -> [] end)

    for skill_id <- @eligible_ids do
      caster = player(%{skill_id: skill_id, level: 1})
      assert {:instant, encore} = Interpreter.begin_cast(caster, @encore_id, 1, :self)

      assert {:instant, _replayed} =
               Interpreter.begin_encore_replay(encore, encore.last_song, :self)

      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert definition.after_cast_delay == []
    end

    assert BdEncore.definition().after_cast_delay == []
  end

  @tag game_mode: :pre_renewal
  test "classic replay starts one Dissonance field and commits half SP without delay" do
    caster = player(%{skill_id: 317, level: 5})
    reject(&Combat.execute_magic_splash/4)

    expect(Performance, :perform, fn performer, _definition, 5, nil, [], opts ->
      assert performer.character_id == caster.character_id
      assert opts[:tick] == :dissonance
      assert opts[:kind] == :song
      {:ok, Song.remember(performer, 317, 5)}
    end)

    assert {:ok, encore} = Interpreter.cast(caster, @encore_id, 1, :self)
    assert encore.stats.current_state.sp == 100

    assert {:instant, updated} =
             Interpreter.begin_encore_replay(encore, encore.last_song, :self)

    assert updated.stats.current_state.sp == 85
    assert updated.skill_cooldowns == %{}
    assert updated.act_delay_until == 0
    assert updated.last_song == %{skill_id: 317, level: 5}
  end

  @tag game_mode: :pre_renewal
  test "classic remembered attempt checks its cooldown after Encore commits" do
    caster = player(%{skill_id: 319, level: 1})
    reject(&Performance.perform/6)

    assert {:instant, encore} = Interpreter.begin_cast(caster, @encore_id, 1, :self)

    blocked =
      put_in(encore.skill_cooldowns[319], System.monotonic_time(:millisecond) + 10_000)

    assert {:error, :on_cooldown} =
             Interpreter.begin_encore_replay(blocked, blocked.last_song, :self)

    assert blocked.stats.current_state.sp == 100
    assert Map.keys(blocked.skill_cooldowns) == [319]
    assert blocked.act_delay_until == 0
  end
end
