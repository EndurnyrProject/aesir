defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrLexTurnundeadTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrLexaeterna
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrLexdivina
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrTurnundead
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(Combat)
    Mimic.copy(TargetResolver)
    Mimic.copy(PlayerState)
    Mimic.copy(StatusInterpreter)
    Mimic.copy(StatusStorage)
  end

  defmodule TargetState do
    defstruct [:combatant, :stats]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
    def get_stats(%__MODULE__{stats: stats}), do: stats
  end

  test "Lex Divina uses the Renewal duration and SP tables" do
    assert {:ok, definition} = Catalog.by_id(76)
    assert definition.name == :pr_lexdivina
    assert definition.range == 5
    assert definition.sp_cost == [20, 20, 20, 20, 20, 18, 16, 14, 12, 10]

    assert definition.duration == [
             30_000,
             35_000,
             40_000,
             45_000,
             50_000,
             60_000,
             60_000,
             60_000,
             60_000,
             60_000
           ]
  end

  test "Lex Divina removes existing Silence instead of refreshing it" do
    {:ok, definition} = Catalog.by_id(76)
    caster = %PlayerState{character_id: 1_000}
    target_id = 2_000

    stub(Combat, :resolve_combatant, fn ^target_id -> {:ok, %{unit_type: :mob}} end)
    stub(StatusStorage, :has_status?, fn :mob, ^target_id, :sc_silence -> true end)
    expect(StatusInterpreter, :remove_status, fn :mob, ^target_id, :sc_silence -> :ok end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = PrLexdivina.cast(caster, {:unit, target_id}, 1, definition)
  end

  test "Lex Divina delays a certain Silence application for one second" do
    {:ok, definition} = Catalog.by_id(76)
    caster = %PlayerState{character_id: 1_000}
    target_id = 2_000

    stub(Combat, :resolve_combatant, fn ^target_id -> {:ok, %{unit_type: :mob}} end)
    stub(StatusStorage, :has_status?, fn :mob, ^target_id, :sc_silence -> false end)

    assert {:ok, ^caster} = PrLexdivina.cast(caster, {:unit, target_id}, 3, definition)

    assert_receive {:skill,
                    {:deferred, PrLexdivina,
                     %{unit_type: :mob, target_id: ^target_id, caster_id: 1_000, duration: 40_000}}},
                   1_100
  end

  test "the delayed Lex Divina application carries its certain chance and selected duration" do
    expect(StatusInterpreter, :apply_status, fn :mob, 2_000, :sc_silence, params ->
      assert params[:caster_id] == 1_000
      assert params[:success_rate] == 100
      assert params[:duration] == 40_000
      :ok
    end)

    assert :ok = PrLexdivina.apply_silence(:mob, 2_000, 1_000, 40_000)
  end

  test "PlayerSession applies Lex Divina's delayed toggle through its message handler" do
    expect(StatusInterpreter, :apply_status, fn :mob, 2_000, :sc_silence, params ->
      assert params[:caster_id] == 1_000
      assert params[:duration] == 40_000
      assert params[:success_rate] == 100
      :ok
    end)

    payload = %{unit_type: :mob, target_id: 2_000, caster_id: 1_000, duration: 40_000}

    assert {:noreply, %{marker: :unchanged}} =
             PlayerSession.handle_info(
               {:skill, {:deferred, PrLexdivina, payload}},
               %{marker: :unchanged, game_state: %{}}
             )
  end

  test "Turn Undead exposes the exact capped Renewal instant-kill score" do
    caster = %{luk: 50, int: 80, base_level: 99}
    target = %{hp: 1, max_hp: 1_000}

    assert PrTurnundead.instant_kill_score(caster, target, 10) == 629

    assert PrTurnundead.instant_kill_score(%{luk: 400, int: 400, base_level: 300}, target, 10) ==
             700
  end

  test "Turn Undead scales its Renewal MATK fallback by skill level" do
    assert PrTurnundead.fallback_skill_ratio(1) == 100
    assert PrTurnundead.fallback_skill_ratio(10) == 1_000
  end

  test "Turn Undead exposes its complete cast and targeting metadata" do
    assert {:ok, definition} = Catalog.by_id(77)

    assert definition.name == :pr_turnundead
    assert definition.target_type == :target_enemy
    assert definition.damage_kind == :magic
    assert definition.element == :holy
    assert definition.range == 5
    assert definition.cast_time == List.duplicate(800, 10)
    assert definition.fixed_cast_time == List.duplicate(200, 10)
    assert definition.after_cast_delay == List.duplicate(3_000, 10)
    assert definition.sp_cost == List.duplicate(20, 10)
  end

  test "Turn Undead's failed roll bypasses MDEF while preserving its magic hit path" do
    {:ok, definition} = Catalog.by_id(77)
    target_id = 2_000

    target = %TargetState{
      combatant: %{race: :undead, element: {:undead, 1}},
      stats: %{hp: 100, max_hp: 100}
    }

    stub(TargetResolver, :resolve, fn ^target_id -> {:ok, self(), target, :mob} end)
    stub(PlayerState, :get_stats, fn _caster -> %{luk: 0, int: 0, base_level: 0} end)

    :rand.seed(:exsss, {1, 2, 3})

    expect(Combat, :execute_magic_attack, fn %{character_id: 1_000}, ^target_id, opts ->
      assert opts[:skill_ratio] == 100
      assert opts[:element] == :holy
      assert opts[:ignore_mdef]
      assert opts[:skip_range]
      :ok
    end)

    assert {:ok, %{character_id: 1_000}} =
             PrTurnundead.cast(%{character_id: 1_000}, {:unit, target_id}, 1, definition)
  end

  test "Lex Aeterna uses the Renewal targeting, cost, duration, and delay data" do
    assert {:ok, definition} = Catalog.by_id(78)
    assert definition.name == :pr_lexaeterna
    assert definition.range == 9
    assert definition.sp_cost == [10]
    assert definition.duration == [600_000]
    assert definition.after_cast_delay == [3_000]
  end

  test "Lex Aeterna applies its status with the configured duration" do
    {:ok, definition} = Catalog.by_id(78)
    caster = %PlayerState{character_id: 1_000}
    target_id = 2_000

    stub(Combat, :resolve_combatant, fn ^target_id -> {:ok, %{unit_type: :mob}} end)

    expect(StatusInterpreter, :apply_status, fn :mob, ^target_id, :sc_aeterna, params ->
      assert params[:caster_id] == 1_000
      assert params[:duration] == 600_000
      :ok
    end)

    assert {:ok, ^caster} = PrLexaeterna.cast(caster, {:unit, target_id}, 1, definition)
  end

  test "Turn Undead rejects a non-undead target before its cast can charge costs" do
    target_id = 2_000

    expect(Combat, :resolve_combatant, fn ^target_id ->
      {:ok, %{race: :formless, element: {:water, 1}}}
    end)

    assert {:error, :invalid_target} =
             PrTurnundead.validate(%{}, {:unit, target_id}, 1, %{})
  end

  test "Turn Undead accepts an undead-element target" do
    target_id = 2_000

    expect(Combat, :resolve_combatant, fn ^target_id ->
      {:ok, %{race: :formless, element: {:undead, 1}}}
    end)

    assert :ok = PrTurnundead.validate(%{}, {:unit, target_id}, 1, %{})
  end
end
