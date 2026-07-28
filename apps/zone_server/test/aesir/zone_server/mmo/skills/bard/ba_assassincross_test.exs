defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaAssassincrossTest do
  use ExUnit.Case, async: false
  use Mimic

  import Bitwise
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaAssassincross
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Sunset table" do
    assert {:ok, BaAssassincross} = Catalog.active_module_for(:ba_assassincross)
    assert {:ok, definition} = Catalog.by_id(320)

    assert definition.name == :ba_assassincross
    assert definition.display_name == "Assassin Cross of Sunset"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 15
    assert definition.duration == List.duplicate(180_000, 10)
    assert definition.sp_cost == Enum.to_list(40..85//5)
    assert definition.cast_time == List.duplicate(1_000, 10)
    assert definition.fixed_cast_time == List.duplicate(300, 10)
    assert definition.after_cast_delay == List.duplicate(300, 10)
    assert definition.cooldown == List.duplicate(20_000, 10)
  end

  test "completion snapshots the exact level-only ASPD formula and remembers Sunset" do
    caster = player()

    for level <- 1..10 do
      expected = if level == 10, do: 20, else: 2 * level - 1

      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_assncross, params ->
        assert params[:val2] == expected
        assert params[:duration] == 180_000
        :ok
      end)

      assert {:ok, result} =
               BaAssassincross.cast(caster, :self, level, BaAssassincross.definition())

      assert result.last_song == %{skill_id: 320, level: level}
    end
  end

  test "dynamic cost uses Bard cost ordering" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_adaptation, duration: 10_000)

    assert %Cost{sp: 32, sp_requirement: 32} =
             BaAssassincross.dynamic_cost(cost_state(), :self, 1, BaAssassincross.definition())
  end

  test "completion excludes the caster under a real Quagmire status" do
    caster = player()
    :ok = StatusStorage.apply_status(:player, 1, :sc_quagmire, duration: 10_000, val2: 5)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, result} = BaAssassincross.cast(caster, :self, 1, BaAssassincross.definition())
    assert result.last_song == %{skill_id: 320, level: 1}
  end

  test "completion excludes the caster in the real Mado option shape" do
    caster = %{player() | option: player().option ||| Option.id(:madogear)}
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, result} = BaAssassincross.cast(caster, :self, 1, BaAssassincross.definition())
    assert result.last_song == %{skill_id: 320, level: 1}
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
