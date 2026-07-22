defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSlowpoisonStrecoveryTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrSlowpoison
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrStrecovery
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DeadlyPoison
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Poison
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SlowPoison
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :verify_on_exit!

  setup do
    Mimic.copy(Combat)
    Mimic.copy(Helpers)
    Mimic.copy(StatusInterpreter)
    Mimic.copy(StatusStorage)
  end

  test "Slow Poison uses Renewal id, cost, range, and duration data" do
    assert {:ok, definition} = Catalog.by_id(71)
    assert definition.name == :pr_slowpoison
    assert definition.range == 9
    assert definition.sp_cost == [6, 8, 10, 12]
    assert definition.duration == [10_000, 20_000, 30_000, 40_000]
  end

  test "Slow Poison applies its status to the caster for the selected duration" do
    {:ok, definition} = Catalog.by_id(71)
    caster = %{character_id: 1_000}

    expect(StatusInterpreter, :apply_status, fn :player, 1_000, :sc_slowpoison, params ->
      assert params[:caster_id] == 1_000
      assert params[:duration] == 30_000
      :ok
    end)

    assert {:ok, ^caster} = PrSlowpoison.cast(caster, :self, 3, definition)
  end

  test "Slow Poison returns the status-application error" do
    {:ok, definition} = Catalog.by_id(71)
    caster = %{character_id: 1_000}

    expect(StatusInterpreter, :apply_status, fn :player, 1_000, :sc_slowpoison, _params ->
      {:error, :immune}
    end)

    assert {:error, :immune} = PrSlowpoison.cast(caster, :self, 1, definition)
  end

  test "Status Recovery uses Renewal id, cost, range, delay, and blind duration" do
    assert {:ok, definition} = Catalog.by_id(72)
    assert definition.name == :pr_strecovery
    assert definition.range == 9
    assert definition.sp_cost == [5]
    assert definition.after_cast_delay == [2_000]
    assert definition.duration == [18_000]
  end

  test "Status Recovery removes every supported non-undead body-state status" do
    {:ok, definition} = Catalog.by_id(72)
    caster = %{character_id: 1_000}
    target_id = 2_000

    stub(Combat, :resolve_combatant, fn ^target_id ->
      {:ok, %{unit_type: :player, race: :player_human}}
    end)

    for status <- [:sc_stone, :sc_freeze, :sc_stun, :sc_sleep] do
      expect(StatusInterpreter, :remove_status, fn :player, ^target_id, ^status -> :ok end)
    end

    assert {:ok, ^caster} = PrStrecovery.cast(caster, {:unit, target_id}, 1, definition)
  end

  test "Status Recovery returns the target-resolution error" do
    {:ok, definition} = Catalog.by_id(72)
    caster = %{character_id: 1_000}

    expect(Combat, :resolve_combatant, fn 2_000 -> {:error, :target_not_found} end)

    assert {:error, :target_not_found} =
             PrStrecovery.cast(caster, {:unit, 2_000}, 1, definition)
  end

  test "Status Recovery delays Blind on an undead target by one second" do
    {:ok, definition} = Catalog.by_id(72)
    caster = %{character_id: 1_000}
    target_id = 2_000

    stub(Combat, :resolve_combatant, fn ^target_id ->
      {:ok, %{unit_type: :mob, race: :undead}}
    end)

    reject(&StatusInterpreter.remove_status/3)

    assert {:ok, ^caster} = PrStrecovery.cast(caster, {:unit, target_id}, 1, definition)

    assert_receive {:skill_deferred, PrStrecovery,
                    %{unit_type: :mob, target_id: ^target_id, caster_id: 1_000}},
                   1_100
  end

  test "Status Recovery delays Blind on an undead-element target" do
    {:ok, definition} = Catalog.by_id(72)
    caster = %{character_id: 1_000}
    target_id = 2_000

    stub(Combat, :resolve_combatant, fn ^target_id ->
      {:ok, %{unit_type: :mob, race: :formless, element: {:undead, 1}}}
    end)

    assert {:ok, ^caster} = PrStrecovery.cast(caster, {:unit, target_id}, 1, definition)

    assert_receive {:skill_deferred, PrStrecovery,
                    %{unit_type: :mob, target_id: ^target_id, caster_id: 1_000}},
                   1_100
  end

  test "Status Recovery cures a demon instead of treating it as undead" do
    {:ok, definition} = Catalog.by_id(72)
    caster = %{character_id: 1_000}
    target_id = 2_000

    stub(Combat, :resolve_combatant, fn ^target_id ->
      {:ok, %{unit_type: :mob, race: :demon, element: {:fire, 1}}}
    end)

    for status <- [:sc_stone, :sc_freeze, :sc_stun, :sc_sleep] do
      expect(StatusInterpreter, :remove_status, fn :mob, ^target_id, ^status -> :ok end)
    end

    assert {:ok, ^caster} = PrStrecovery.cast(caster, {:unit, target_id}, 1, definition)
  end

  test "the delayed Status Recovery effect applies 18 seconds of Blind" do
    expect(StatusInterpreter, :apply_status, fn :mob, 2_000, :sc_blind, params ->
      assert params[:caster_id] == 1_000
      assert params[:duration] == 18_000
      :ok
    end)

    assert :ok = PrStrecovery.apply_undead_effect(:mob, 2_000, 1_000)
  end

  test "Poison suppresses its damage tick while Slow Poison is active" do
    target = {:player, 2_000}
    instance = %StatusEntry{type: :sc_poison}
    context = %{target: %{max_hp: 1_000}}

    stub(StatusStorage, :has_status?, fn :player, 2_000, :sc_slowpoison -> true end)
    reject(&Helpers.deal_damage/2)

    assert {:ok, ^instance} = Poison.on_tick(target, instance, context)
  end

  test "Poison still damages when Slow Poison is absent" do
    target = {:player, 2_000}
    instance = %StatusEntry{type: :sc_poison}
    context = %{target: %{max_hp: 1_000}}

    stub(StatusStorage, :has_status?, fn :player, 2_000, :sc_slowpoison -> false end)
    expect(Helpers, :deal_damage, fn ^target, 17 -> :ok end)

    assert {:ok, ^instance} = Poison.on_tick(target, instance, context)
  end

  test "Deadly Poison suppresses its damage tick while Slow Poison is active" do
    target = {:player, 2_000}
    instance = %StatusEntry{type: :sc_dpoison}
    context = %{target: %{max_hp: 1_000, hp: 1_000}}

    stub(StatusStorage, :has_status?, fn :player, 2_000, :sc_slowpoison -> true end)
    reject(&Helpers.deal_damage/2)

    assert {:ok, ^instance} = DeadlyPoison.on_tick(target, instance, context)
  end

  test "Deadly Poison still damages when Slow Poison is absent" do
    target = {:player, 2_000}
    instance = %StatusEntry{type: :sc_dpoison}
    context = %{target: %{max_hp: 1_000, hp: 1_000}}

    stub(StatusStorage, :has_status?, fn :player, 2_000, :sc_slowpoison -> false end)
    expect(Helpers, :deal_damage, fn ^target, 22 -> :ok end)

    assert {:ok, ^instance} = DeadlyPoison.on_tick(target, instance, context)
  end

  test "Slow Poison restores normal natural-regen rates without adding a fake bonus" do
    instance = %StatusEntry{type: :sc_slowpoison}

    assert SlowPoison.modifiers(instance, %{}) == %{}

    stub(StatusStorage, :has_status?, fn :player, 2_000, :sc_slowpoison -> true end)

    assert Poison.modifiers(instance, %{unit_type: :player, target_id: 2_000}) == %{
             def2_rate: -25
           }

    assert DeadlyPoison.modifiers(instance, %{unit_type: :player, target_id: 2_000}) == %{
             def_rate: -25
           }
  end
end
