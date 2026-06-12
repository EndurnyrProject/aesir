defmodule Aesir.ZoneServer.Mmo.StatusEffect.DefinitionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEntry

  defmodule MinimalStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition, id: :sc_test_minimal
  end

  defmodule FullStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_full,
      properties: [:debuff, :damage_over_time],
      calc_flags: [:def],
      flags: [:no_move],
      prevented_by: [:sc_refresh],
      conflicts_with: [:sc_aeterna],
      immunity: [:boss, :plant],
      cleanse: [:sc_slowpoison],
      resistance_type: :physical,
      tick_interval: 1_000,
      initial_phase: :wait,
      duration: 30_000

    @impl true
    def modifiers(_instance, _context), do: %{def2: -25}

    @impl true
    def on_apply(_target, instance, _context), do: {:ok, %{instance | val1: 99}}

    @impl true
    def on_tick(_target, _instance, _context), do: :remove

    @impl true
    def on_damage(_target, _instance, %{element: :earth}, _context), do: :remove
    def on_damage(_target, instance, _damage_info, _context), do: {:ok, instance}
  end

  describe "use macro" do
    test "generates id/0 from metadata" do
      assert MinimalStatus.id() == :sc_test_minimal
      assert FullStatus.id() == :sc_test_full
    end

    test "minimal definition fills metadata defaults" do
      metadata = MinimalStatus.metadata()

      assert metadata.id == :sc_test_minimal
      assert metadata.properties == []
      assert metadata.calc_flags == []
      assert metadata.flags == []
      assert metadata.prevented_by == []
      assert metadata.conflicts_with == []
      assert metadata.end_on_start == []
      assert metadata.immunity == []
      assert metadata.cleanse == []
      assert metadata.initial_phase == nil
      assert metadata.tick_interval == nil
      assert metadata.duration == nil
    end

    test "full definition keeps all declared metadata" do
      metadata = FullStatus.metadata()

      assert metadata.properties == [:debuff, :damage_over_time]
      assert metadata.calc_flags == [:def]
      assert metadata.flags == [:no_move]
      assert metadata.prevented_by == [:sc_refresh]
      assert metadata.conflicts_with == [:sc_aeterna]
      assert metadata.immunity == [:boss, :plant]
      assert metadata.cleanse == [:sc_slowpoison]
      assert metadata.resistance_type == :physical
      assert metadata.tick_interval == 1_000
      assert metadata.initial_phase == :wait
      assert metadata.duration == 30_000
    end
  end

  describe "default callbacks" do
    setup do
      instance = %StatusEntry{type: :sc_test_minimal, state: %{}, phase: nil}
      %{instance: instance, target: {:player, 1}}
    end

    test "modifiers/2 returns empty map", %{instance: instance} do
      assert MinimalStatus.modifiers(instance, %{}) == %{}
    end

    test "on_apply/3 returns instance unchanged", %{instance: instance, target: target} do
      assert {:ok, ^instance} = MinimalStatus.on_apply(target, instance, %{})
    end

    test "on_expire/3 returns :ok", %{instance: instance, target: target} do
      assert :ok = MinimalStatus.on_expire(target, instance, %{})
    end

    test "on_tick/3 returns instance unchanged", %{instance: instance, target: target} do
      assert {:ok, ^instance} = MinimalStatus.on_tick(target, instance, %{})
    end

    test "on_damage/4 returns instance unchanged", %{instance: instance, target: target} do
      damage_info = %{damage: 100, element: :neutral}
      assert {:ok, ^instance} = MinimalStatus.on_damage(target, instance, damage_info, %{})
    end
  end

  describe "overridden callbacks" do
    setup do
      instance = %StatusEntry{type: :sc_test_full, val1: 0, state: %{}, phase: :wait}
      %{instance: instance, target: {:player, 1}}
    end

    test "modifiers/2 uses the override", %{instance: instance} do
      assert FullStatus.modifiers(instance, %{}) == %{def2: -25}
    end

    test "on_apply/3 uses the override", %{instance: instance, target: target} do
      assert {:ok, %StatusEntry{val1: 99}} = FullStatus.on_apply(target, instance, %{})
    end

    test "on_tick/3 uses the override", %{instance: instance, target: target} do
      assert :remove = FullStatus.on_tick(target, instance, %{})
    end

    test "on_damage/4 pattern matches on damage info", %{instance: instance, target: target} do
      assert :remove = FullStatus.on_damage(target, instance, %{element: :earth}, %{})
      assert {:ok, ^instance} = FullStatus.on_damage(target, instance, %{element: :fire}, %{})
    end
  end

  describe "compile-time metadata validation" do
    test "raises when id is missing" do
      assert_raise ArgumentError, ~r/id/, fn ->
        defmodule MissingId do
          use Aesir.ZoneServer.Mmo.StatusEffect.Definition, properties: [:debuff]
        end
      end
    end

    test "raises on unknown metadata key" do
      assert_raise ArgumentError, ~r/unknown/i, fn ->
        defmodule UnknownKey do
          use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
            id: :sc_bad,
            phases: %{wait: %{}}
        end
      end
    end

    test "raises on unknown property" do
      assert_raise ArgumentError, ~r/properties/, fn ->
        defmodule BadProperty do
          use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
            id: :sc_bad_prop,
            properties: [:debuf]
        end
      end
    end

    test "raises on invalid tick_interval" do
      assert_raise ArgumentError, ~r/tick_interval/, fn ->
        defmodule BadTick do
          use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
            id: :sc_bad_tick,
            tick_interval: 0
        end
      end
    end
  end
end
