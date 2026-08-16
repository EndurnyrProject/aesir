defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GuildAuraTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.GuildAuraSource
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @master_id 1
  @member_id 2
  @outsider_id 3
  @guild_id 5

  defp register_player(id, guild_id, {x, y}) do
    player =
      %Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: "prontera",
        last_x: x,
        last_y: y,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 12
      }
      |> PlayerState.new()
      |> Map.put(:guild_id, guild_id)

    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_unit(:player, id, x, y, "prontera")
    player
  end

  defp aura_instance(levels \\ [val1: 3]) do
    struct!(
      %StatusEntry{type: :sc_guild_aura_source, val1: 0, val2: 0, val3: 0, val4: 0, state: %{}},
      levels
    )
  end

  defp tick(instance) do
    GuildAuraSource.on_tick({:player, @master_id}, instance, %{target_id: @master_id})
  end

  defp active_statuses(char_id) do
    :player |> StatusStorage.get_unit_statuses(char_id) |> Enum.map(& &1.type) |> Enum.sort()
  end

  test "a tick buffs same-guild players in radius with the learned levels" do
    register_player(@master_id, @guild_id, {10, 10})
    register_player(@member_id, @guild_id, {11, 10})
    register_player(@outsider_id, 0, {10, 11})

    {:ok, _} = tick(aura_instance(val1: 3, val2: 1))

    assert :sc_gd_leadership in active_statuses(@member_id)
    assert :sc_gd_glorywounds in active_statuses(@member_id)
    refute :sc_gd_soulcold in active_statuses(@member_id)

    assert Interpreter.get_all_modifiers(:player, @member_id) == %{str: 3, vit: 1}

    assert active_statuses(@outsider_id) == []
  end

  test "the master is excluded by default and included via config" do
    register_player(@master_id, @guild_id, {10, 10})

    {:ok, _} = tick(aura_instance())
    assert active_statuses(@master_id) == []

    Application.put_env(:zone_server, :guild_aura_affects_master, true)
    on_exit(fn -> Application.delete_env(:zone_server, :guild_aura_affects_master) end)

    {:ok, _} = tick(aura_instance())
    assert :sc_gd_leadership in active_statuses(@master_id)
  end

  test "a guildmate outside the 2-cell radius is not buffed" do
    register_player(@master_id, @guild_id, {10, 10})
    register_player(@member_id, @guild_id, {13, 10})

    {:ok, _} = tick(aura_instance())

    assert active_statuses(@member_id) == []
  end

  test "member buffs expire on their own shortly after leaving the radius" do
    register_player(@master_id, @guild_id, {10, 10})
    register_player(@member_id, @guild_id, {11, 10})

    {:ok, _} = tick(aura_instance())

    [entry] = StatusStorage.get_unit_statuses(:player, @member_id)
    assert entry.type == :sc_gd_leadership
    now = System.monotonic_time(:millisecond)
    assert entry.expires_at > now
    assert entry.expires_at <= now + 2_500
  end

  test "buffing another player publishes that player's async stat refresh" do
    register_player(@master_id, @guild_id, {10, 10})
    register_player(@member_id, @guild_id, {11, 10})
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{@member_id}")

    {:ok, _} = tick(aura_instance())

    assert_receive :recalculate_stats
  end

  test "the source definition is permanent - an idle master keeps emitting" do
    definition = Aesir.ZoneServer.Mmo.StatusEffect.Registry.get_definition(:sc_guild_aura_source)
    assert definition.permanent == true
  end

  test "a despawned master ticks as a safe no-op" do
    assert {:ok, _} = tick(aura_instance())
  end
end
