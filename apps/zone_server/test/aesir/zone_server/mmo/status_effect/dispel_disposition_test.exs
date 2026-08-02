defmodule Aesir.ZoneServer.Mmo.StatusEffect.DispelDispositionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects

  describe "classic debuffs" do
    test "are dispellable, because rAthena's Dispell removes debuffs too" do
      for id <- [
            :sc_poison,
            :sc_stun,
            :sc_curse,
            :sc_silence,
            :sc_blind,
            :sc_bleeding,
            :sc_freeze,
            :sc_stone
          ] do
        module = module_for!(id)

        refute module.metadata().no_dispel,
               "#{inspect(module)} must stay dispellable: rAthena's status_db carries no " <>
                 "NoDispell flag for it, and SA_DISPELL ends every status that lacks the flag " <>
                 "regardless of buff/debuff. See src/map/skills/mage/dispell.cpp."
      end
    end
  end

  describe "statuses rAthena flags NoDispell" do
    test "survive dispel" do
      for id <- [
            :sc_hiding,
            :sc_cloaking,
            :sc_pneuma,
            :sc_safetywall,
            :sc_poembragi,
            :sc_agifood,
            :sc_cp_weapon,
            :sc_cp_shield,
            :sc_cp_armor,
            :sc_cp_helm
          ] do
        module = module_for!(id)

        assert module.metadata().no_dispel,
               "#{inspect(module)} must survive dispel: its rAthena status_db entry carries NoDispell: true."
      end
    end
  end

  describe "dispel disposition completeness" do
    # The disposition is a required metadata key rather than a defaulted one, so the
    # compiler enforces it and no status can reach this suite without one. Asserting
    # over Effects.all() instead would pass vacuously the moment the key regained a
    # default - the exact silently-dispellable regression this guards against.
    test "a status definition that records no disposition fails to compile" do
      assert_raise ArgumentError, ~r/no_dispel/, fn ->
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.StatusEffect.DispelDispositionTest.NoDisposition do
          use Aesir.ZoneServer.Mmo.StatusEffect.Definition, id: :sc_test_no_disposition
        end
        """)
      end
    end
  end

  defp module_for!(id) do
    Enum.find(Effects.all(), &(&1.id() == id)) ||
      flunk("no implemented status module for #{inspect(id)}")
  end
end
