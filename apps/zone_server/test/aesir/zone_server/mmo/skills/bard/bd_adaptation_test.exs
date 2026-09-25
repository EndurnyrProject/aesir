defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdAdaptationTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BdAdaptation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adaptation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  @tag game_mode: :renewal
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

  @tag game_mode: :renewal
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

  @tag game_mode: :renewal
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
    |> Aesir.ZoneServer.PlayerStateFixture.build()
  end

  @tag game_mode: :pre_renewal
  test "classic carries the source's instant cast and SP" do
    {:ok, definition} = Catalog.by_id(304)
    assert definition.sp_cost == [1]
    assert definition.cast_time == [0]
    assert definition.fixed_cast_time == [0]
    assert definition.after_cast_delay == []
    assert definition.cooldown == []
  end

  @tag game_mode: :pre_renewal
  test "classic refuses Adaptation without an active performing lock" do
    assert {:error, :not_performing} =
             BdAdaptation.validate(game_state(1), :self, 1, BdAdaptation.definition())
  end

  @tag game_mode: :pre_renewal
  test "classic cast requires 1 SP, consumes none, and ends an active performance" do
    register_performer()
    assert StatusStorage.has_status?(:player, 1_000, :sc_dancing)
    test_pid = self()

    stub(Unit, :destroy_async, fn 77 ->
      send(test_pid, :destroy_requested)
      :ok
    end)

    assert {:ok, updated} = Interpreter.cast(game_state(1), 304, 1, :self)
    assert_received :destroy_requested
    refute StatusStorage.has_status?(:player, 1_000, :sc_dancing)
    assert updated.stats.current_state.sp == 1
    assert updated.skill_cooldowns == %{}
    assert updated.act_delay_until == 0
  end

  @tag game_mode: :pre_renewal
  test "classic cast with no SP fails before status application" do
    register_performer()
    reject(&Unit.destroy_async/1)
    assert {:error, :insufficient_sp} = Interpreter.cast(game_state(0), 304, 1, :self)
  end

  defp register_performer do
    player =
      PlayerState.new(%Character{
        id: 1_000,
        account_id: 1_000,
        name: "Bard",
        last_map: "prontera",
        last_x: 10,
        last_y: 10,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 19
      })

    :ok = UnitRegistry.register_player(player, self())

    :ok =
      StatusInterpreter.apply_status(:player, 1_000, :sc_dancing,
        caster_id: 1_000,
        val1: 319,
        val2: 77,
        duration: 60_000,
        state: %{upkeep: 5, ticks: 0}
      )
  end
end
