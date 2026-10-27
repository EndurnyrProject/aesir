defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EquipDisplayStatusesTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

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

  test "equip display statuses are player-only non-gameplay definitions kept through death" do
    for {status_id, module_name, _symbol, display_field, display_value} <- @statuses do
      module = Module.concat(Effects, module_name)
      metadata = module.metadata()

      assert module in Effects.all()
      assert module.id() == status_id
      assert metadata.target_types == [:player]
      refute metadata.permanent
      assert metadata.no_save == (status_id != :sc_summer)
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

  describe "starting a display status" do
    setup :setup_ets_tables

    setup do
      player_id = :rand.uniform(100_000)
      :ok = UnitRegistry.register_player(player_state(player_id), self())
      %{player_id: player_id}
    end

    test "a timed start expires after its duration and an infinite start never expires", %{
      player_id: player_id
    } do
      for {status_id, _module_name, _symbol, _display_field, _display_value} <- @statuses do
        before = System.monotonic_time(:millisecond)

        assert :ok =
                 Interpreter.apply_status(:player, player_id, status_id,
                   caster_id: player_id,
                   val1: 1,
                   duration: 600_000
                 )

        after_start = System.monotonic_time(:millisecond)
        %{expires_at: expires_at} = StatusStorage.get_status(:player, player_id, status_id)
        assert is_integer(expires_at)
        assert expires_at >= before + 600_000
        assert expires_at <= after_start + 600_000

        :ok = Interpreter.remove_status(:player, player_id, status_id)

        assert :ok =
                 Interpreter.apply_status(:player, player_id, status_id,
                   caster_id: player_id,
                   val1: 1,
                   duration: :infinite
                 )

        assert %{expires_at: nil} = StatusStorage.get_status(:player, player_id, status_id)
        :ok = Interpreter.remove_status(:player, player_id, status_id)
      end
    end

    test "Summer blocks attacking", %{player_id: player_id} do
      assert Interpreter.can_attack?(:player, player_id)

      assert :ok =
               Interpreter.apply_status(:player, player_id, :sc_summer,
                 caster_id: player_id,
                 val1: 1,
                 duration: :infinite
               )

      refute Interpreter.can_attack?(:player, player_id)
    end
  end

  defp player_state(player_id) do
    %Character{
      id: player_id,
      account_id: player_id,
      name: "DisplayTest",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
    |> PlayerState.new()
  end
end
