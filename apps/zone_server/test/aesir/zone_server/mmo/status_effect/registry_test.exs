defmodule Aesir.ZoneServer.Mmo.StatusEffect.RegistryTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  defmodule TestStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_registry_test,
      properties: [:debuff],
      immunity: [:boss],
      icon: :provoke,
      opt2: :poison
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
  end
end
