defmodule Aesir.ZoneServer.Mmo.StatusEffect.DealtDamageTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule ProcStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_proc,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def on_dealt_damage(target, instance, hit_info, _context) do
      send(self(), {:hook_ran, self(), target, hit_info})
      {:ok, instance, [{:auto_cast, :mg_firebolt, 3, hit_info.target}]}
    end
  end

  defmodule InertStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_inert,
      no_dispel: false,
      properties: [:buff]
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  defp setup_player_mock(char_id) do
    stub(UnitRegistry, :get_unit_info, fn :player, ^char_id ->
      {:ok,
       %{
         unit_id: char_id,
         unit_type: :player,
         race: :formless,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 100,
           max_sp: 50,
           hp: 100,
           sp: 50,
           level: 1,
           base_level: 1,
           str: 1,
           agi: 1,
           vit: 1,
           int: 1,
           dex: 1,
           luk: 1,
           mdef: 0
         }
       }}
    end)
  end

  describe "on_dealt_damage/3" do
    test "returns the auto-cast follow-ups of an implementing status" do
      setup_player_mock(1)
      Registry.register_module(ProcStatus)
      :ok = Interpreter.apply_status(:player, 1, :sc_test_proc)

      hit_info = %{target: {:mob, 2001}, damage: 50, element: :neutral}

      assert [{:auto_cast, :mg_firebolt, 3, {:mob, 2001}}] =
               Interpreter.on_dealt_damage(:player, 1, hit_info)

      assert_received {:hook_ran, _pid, {:player, 1}, ^hit_info}
    end

    # The hottest loop in the server: with nothing implementing the hook the
    # dispatch must not even read the attacker's statuses, let alone build a
    # context per status. Only the registry read is allowed.
    #
    # The empty set is stubbed rather than taken from the real registry, which
    # SC_AUTOSPELL has implemented the hook in since Task 25 - so the branch is
    # no longer reachable through the loaded definitions, only through a registry
    # that indexes no implementer.
    test "costs one registry read and nothing else when no status implements the hook" do
      stub(Registry, :statuses_implementing, fn :on_dealt_damage -> MapSet.new() end)
      reject(&StatusStorage.get_unit_statuses/2)

      assert Interpreter.on_dealt_damage(:player, 1, %{target: {:mob, 2001}, damage: 50}) == []
    end

    test "does not dispatch to a holder's statuses that do not implement the hook" do
      setup_player_mock(1)
      Registry.register_module(ProcStatus)
      Registry.register_module(InertStatus)
      :ok = Interpreter.apply_status(:player, 1, :sc_test_inert)

      assert Interpreter.on_dealt_damage(:player, 1, %{target: {:mob, 2001}, damage: 50}) == []
      refute_received {:hook_ran, _, _, _}
    end
  end
end
