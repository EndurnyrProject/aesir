defmodule Aesir.ZoneServer.Mmo.StatusEffect.LogoutSaveCatalogTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  @saved [
    :sc_autoguard,
    :sc_autospell,
    :sc_defender,
    :sc_reflectshield,
    :sc_ruwach,
    :sc_sacrifice,
    :sc_spearquicken,
    :sc_sub_weaponproperty,
    :sc_summer,
    :sc_tarotcard
  ]

  @ended [
    :sc_adrenaline2,
    :sc_aeterna,
    :sc_aurablade,
    :sc_concentration,
    :sc_providence,
    :sc_speedup0,
    :sc_speedup1,
    :sc_ankle,
    :sc_bladestop_wait,
    :sc_dancing,
    :sc_hiding,
    :sc_marionette,
    :sc_marionette2,
    :sc_pneuma,
    :sc_safetywall,
    :sc_longing,
    :sc_push_cart
  ]

  setup_all do
    Registry.load_definitions()
    :ok
  end

  defp saved_at_logout?(status_id) do
    definition = Registry.get_definition(status_id)
    not definition.no_save and not definition.remove_on_map_change
  end

  test "a logout saves exactly the agreed statuses" do
    assert Enum.reject(@saved, &saved_at_logout?/1) == []
    assert Enum.filter(@ended, &saved_at_logout?/1) == []
  end

  @tag game_mode: :renewal
  test "a renewal logout saves Wand of Hermode" do
    assert saved_at_logout?(:sc_hermode)
  end

  @tag game_mode: :pre_renewal
  test "a pre-renewal logout ends Wand of Hermode with its field" do
    refute saved_at_logout?(:sc_hermode)
  end
end
