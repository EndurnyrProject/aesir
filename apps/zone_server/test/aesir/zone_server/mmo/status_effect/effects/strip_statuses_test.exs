defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripStatusesTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.{StripArmor, StripHelm}
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 7_014
  @strip_statuses [
    {:sc_stripweapon, :right_hand, :noequipweapon},
    {:sc_stripshield, :left_hand, :noequipshield},
    {:sc_striparmor, :armor, :noequiparmor},
    {:sc_striphelm, :head_top, :noequiphelm}
  ]

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player = player_state()
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_player(@player_id, player.x, player.y, player.map_name)

    :ok
  end

  test "Divest statuses are registered with their blocked equipment slots" do
    Enum.each(@strip_statuses, fn {status_id, strip_slot, icon} ->
      assert %{id: ^status_id, metadata: %{strip_slot: ^strip_slot}, icon: ^icon} =
               Registry.get_definition(status_id)
    end)
  end

  test "Divest Armor and Helm reduce VIT and INT by val2 percent" do
    assert StripArmor.modifiers(entry(:sc_striparmor, 25), %{}) == %{vit: -25}
    assert StripHelm.modifiers(entry(:sc_striphelm, 40), %{}) == %{int: -40}
  end

  test "Divest statuses expire after their supplied duration" do
    Enum.each(@strip_statuses, fn {status_id, _strip_slot, _icon} ->
      assert :ok = Interpreter.apply_status(:player, @player_id, status_id, duration: 30_000)

      assert %StatusEntry{expires_at: expires_at} =
               entry = StatusStorage.get_status(:player, @player_id, status_id)

      assert expires_at > System.monotonic_time(:millisecond)
      assert Interpreter.expire_status_if_current(:player, @player_id, status_id, entry)
      refute StatusStorage.has_status?(:player, @player_id, status_id)
    end)
  end

  defp entry(type, val2), do: %StatusEntry{type: type, val2: val2, state: %{}}

  defp player_state do
    %Character{
      id: @player_id,
      account_id: 8_014,
      name: "StripTarget",
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
