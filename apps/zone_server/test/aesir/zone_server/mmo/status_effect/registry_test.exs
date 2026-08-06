defmodule Aesir.ZoneServer.Mmo.StatusEffect.RegistryTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  defmodule TestStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_registry_test,
      no_dispel: false,
      properties: [:debuff],
      immunity: [:boss],
      icon: :provoke,
      opt2: :poison
  end

  defmodule MovementIntentStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_registry_movement_intent,
      no_dispel: false

    @impl true
    def on_movement_intent(_target, instance, _position, _context), do: {:ok, instance}
  end

  defmodule CommittedActionStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_registry_committed_action,
      no_dispel: false,
      flags: [:no_pick_item]

    @impl true
    def on_committed_action(_target, instance, _action, _context), do: {:ok, instance}
  end

  setup :setup_ets_tables

  describe "register_module/1" do
    test "stores module metadata keyed by status id" do
      :ok = Registry.register_module(TestStatus)

      definition = Registry.get_definition(:sc_registry_test)
      assert definition[:module] == TestStatus
      assert definition[:properties] == [:debuff]
      assert definition[:immunity] == [:boss]
      assert definition[:icon] == :provoke
      assert definition[:opt2] == :poison
    end

    test "registered definition works with PropertyChecker" do
      :ok = Registry.register_module(TestStatus)

      alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
      assert PropertyChecker.debuff?(:sc_registry_test)
      assert PropertyChecker.has_property?(:sc_registry_test, :debuff)
      refute PropertyChecker.prevents_movement?(:sc_registry_test)
    end

    test "indexes only statuses implementing movement intent" do
      :ok = Registry.register_module(TestStatus)
      :ok = Registry.register_module(MovementIntentStatus)

      implementing = Registry.statuses_implementing(:on_movement_intent)
      assert MapSet.member?(implementing, :sc_registry_movement_intent)
      assert MapSet.member?(implementing, :sc_cloaking)
      refute MapSet.member?(implementing, :sc_registry_test)
    end

    test "indexes committed actions and metadata flags independently" do
      :ok = Registry.register_module(TestStatus)
      :ok = Registry.register_module(CommittedActionStatus)

      implementing = Registry.statuses_implementing(:on_committed_action)
      assert MapSet.member?(implementing, :sc_registry_committed_action)
      assert MapSet.member?(implementing, :sc_cloaking)
      refute MapSet.member?(implementing, :sc_registry_test)

      assert MapSet.member?(
               Registry.statuses_with_flag(:no_pick_item),
               :sc_registry_committed_action
             )
    end
  end
end
