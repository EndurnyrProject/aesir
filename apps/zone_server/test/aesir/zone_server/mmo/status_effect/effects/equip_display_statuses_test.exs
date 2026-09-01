defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EquipDisplayStatusesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @statuses [
    {:sc_summer, "Summer", "SC_SUMMER", :option, :summer},
    {:sc_strangelights, "StrangeLights", "SC_STRANGELIGHTS", :icon, :strangelights},
    {:sc_moonstar, "MoonStar", "SC_MOONSTAR", :icon, :moonstar},
    {:sc_super_star, "SuperStar", "SC_SUPER_STAR", :icon, :super_star},
    {:sc_fstone, "Fstone", "SC_FSTONE", :icon, :fstone},
    {:sc_decoration_of_music, "DecorationOfMusic", "SC_DECORATION_OF_MUSIC", :icon,
     :decoration_of_music},
    {:sc_hat_effect, "HatEffect", "SC_HAT_EFFECT", :icon, :hat_effect},
    {:sc_ljosalfar, "Ljosalfar", "SC_LJOSALFAR", :icon, :ljosalfar},
    {:sc_maple_falls, "MapleFalls", "SC_MAPLE_FALLS", :icon, :maple_falls},
    {:sc_mermaid_longing, "MermaidLonging", "SC_MERMAID_LONGING", :icon, :mermaid_longing},
    {:sc_time_accessory, "TimeAccessory", "SC_TIME_ACCESSORY", :icon, :time_accessory}
  ]

  test "equip display statuses are player-only permanent non-gameplay definitions" do
    for {status_id, module_name, _symbol, display_field, display_value} <- @statuses do
      module = Module.concat(Effects, module_name)
      metadata = module.metadata()

      assert module in Effects.all()
      assert module.id() == status_id
      assert metadata.target_types == [:player]
      assert metadata.permanent
      assert metadata.no_save
      assert metadata.no_dispel
      refute metadata.remove_on_death
      assert metadata.calc_flags == []
      assert module.modifiers(%StatusEntry{}, %{}) == %{}
      assert Map.fetch!(metadata, display_field) == display_value
    end
  end

  test "equip display status symbols resolve to their definitions" do
    for {status_id, _module_name, symbol, _display_field, _display_value} <- @statuses do
      assert Resolver.resolve_status(symbol) == {:ok, status_id}
    end
  end
end
