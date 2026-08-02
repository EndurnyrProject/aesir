defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CpStatusesTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.StatusChange
  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 7_004
  @statuses [
    {:sc_cp_weapon, :protectweapon},
    {:sc_cp_shield, :protectshield},
    {:sc_cp_armor, :protectarmor},
    {:sc_cp_helm, :protecthelm}
  ]

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player = player_state()
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_player(@player_id, player.x, player.y, player.map_name)

    :ok
  end

  test "Chemical Protection statuses apply, expose their icons, and expire" do
    Enum.each(@statuses, fn {status_id, icon} ->
      definition = Registry.get_definition(status_id)

      assert definition.properties == [:buff]
      assert definition.no_dispel
      refute definition.no_save
      assert definition.icon == icon

      assert :ok = Interpreter.apply_status(:player, @player_id, status_id, duration: 30_000)

      assert %StatusEntry{expires_at: expires_at} =
               entry = StatusStorage.get_status(:player, @player_id, status_id)

      assert expires_at > System.monotonic_time(:millisecond)

      assert [%StatusChange{on: true, efst: efst, total_ms: 30_000}] =
               StatusDisplay.active_icons(:player, @player_id)
               |> Enum.filter(&(&1.efst == Efst.id(icon)))

      assert efst == Efst.id(icon)
      assert Interpreter.expire_status_if_current(:player, @player_id, status_id, entry)
      refute StatusStorage.has_status?(:player, @player_id, status_id)

      assert [] =
               StatusDisplay.active_icons(:player, @player_id)
               |> Enum.filter(&(&1.efst == Efst.id(icon)))
    end)
  end

  defp player_state do
    %Character{
      id: @player_id,
      account_id: 8_004,
      name: "ChemicalProtectionTarget",
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
