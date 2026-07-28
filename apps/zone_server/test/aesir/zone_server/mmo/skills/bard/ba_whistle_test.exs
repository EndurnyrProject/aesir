defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaWhistleTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaWhistle
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Song
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  Mimic.copy(Song)

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Whistle table" do
    assert {:ok, BaWhistle} = Catalog.active_module_for(:ba_whistle)
    assert {:ok, definition} = Catalog.by_id(319)

    assert definition.name == :ba_whistle
    assert definition.display_name == "Whistle"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 15
    assert definition.duration == List.duplicate(180_000, 10)
    assert definition.sp_cost == Enum.to_list(22..40//2)
    assert definition.cast_time == List.duplicate(1_000, 10)
    assert definition.fixed_cast_time == List.duplicate(300, 10)
    assert definition.after_cast_delay == List.duplicate(300, 10)
    assert definition.cooldown == List.duplicate(20_000, 10)
  end

  test "completion snapshots exact level-only flee and perfect dodge parameters" do
    caster = player()

    for level <- 1..10 do
      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_whistle, params ->
        assert params[:val2] == 18 + 2 * level
        assert params[:val3] == div(level + 1, 2)
        assert params[:duration] == 180_000
        :ok
      end)

      assert {:ok, result} = BaWhistle.cast(caster, :self, level, BaWhistle.definition())
      assert result.last_song == %{skill_id: 319, level: level}
    end
  end

  test "completion replaces an existing song with real status parameters and memory" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_assncross, duration: 10_000, val2: 20)

    assert {:ok, result} = BaWhistle.cast(caster, :self, 3, BaWhistle.definition())
    refute StatusStorage.has_status?(:player, 1, :sc_assncross)
    assert %{val2: 24, val3: 2} = StatusStorage.get_status(:player, 1, :sc_whistle)
    assert result.last_song == %{skill_id: 319, level: 3}
  end

  test "dynamic cost uses Bard cost ordering" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_adaptation, duration: 10_000)

    assert %Cost{sp: 18, sp_requirement: 18} =
             BaWhistle.dynamic_cost(cost_state(), :self, 1, BaWhistle.definition())
  end

  test "a failed snapshot is returned without a replacement state" do
    caster = player()
    expect(Song, :snapshot, fn ^caster, 319, 1, :sc_whistle, _params -> {:error, :failed} end)

    assert {:error, :failed} = BaWhistle.cast(caster, :self, 1, BaWhistle.definition())
    assert Map.fetch!(caster, :last_song) == nil
  end

  test "Quagmire does not exclude a Whistle recipient" do
    caster = player()
    :ok = StatusStorage.apply_status(:player, 1, :sc_quagmire, duration: 10_000, val2: 5)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_whistle, _params -> :ok end)

    assert {:ok, _result} = BaWhistle.cast(caster, :self, 1, BaWhistle.definition())
  end

  defp cost_state do
    %{
      character_id: 1,
      stats: %{current_state: %{hp: 100, sp: 100}, derived_stats: %{max_hp: 100}}
    }
  end

  defp player do
    %Character{
      id: 1,
      account_id: 1,
      name: "Bard",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 19,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: 0
    }
    |> PlayerState.new()
  end
end
