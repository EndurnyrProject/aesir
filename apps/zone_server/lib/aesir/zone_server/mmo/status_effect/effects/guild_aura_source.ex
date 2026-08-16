defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GuildAuraSource do
  @moduledoc """
  Hidden guild-aura carrier (`:sc_guild_aura_source`) on the guild master.

  Applied while the master is online and the guild has any aura skill learned
  (Great Leadership / Glorious Wounds / Cold Heart / Sharp Gaze); vals carry
  the four levels (`val1`-`val4`). Each 1s tick scans radius 2 around the
  master's current cell and applies short-lived flat stat buffs to same-guild
  players; leaving the radius self-heals via buff expiry, so no removal
  bookkeeping exists. The master is excluded unless `guild_aura_affects_master`
  is enabled. Permanent while carried and never persisted - the social handler
  re-applies it on login and on guild skill changes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_guild_aura_source,
    properties: [:buff],
    permanent: true,
    no_dispel: true,
    no_save: true,
    tick_interval: 1_000

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @radius 2
  @buff_duration 2_500
  @aura_statuses [
    {:sc_gd_leadership, :val1},
    {:sc_gd_glorywounds, :val2},
    {:sc_gd_soulcold, :val3},
    {:sc_gd_hawkeyes, :val4}
  ]

  @impl true
  def on_tick({:player, master_id}, instance, _context) do
    pulse(master_id, instance)
    {:ok, instance}
  end

  defp pulse(master_id, instance) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(:player, master_id),
         {:ok, guild_id} <- master_guild(master_id) do
      :player
      |> SpatialIndex.get_units_in_range(map_name, x, y, @radius)
      |> Enum.filter(&aura_target?(&1, master_id, guild_id))
      |> Enum.each(&buff_member(&1, instance))
    else
      _missing -> :ok
    end
  end

  defp master_guild(master_id) do
    case UnitRegistry.get_unit(:player, master_id) do
      {:ok, {_module, %PlayerState{guild_id: guild_id}, _pid}} when guild_id not in [nil, 0] ->
        {:ok, guild_id}

      _other ->
        :error
    end
  end

  defp aura_target?(master_id, master_id, _guild_id), do: Config.guild_aura_affects_master()
  defp aura_target?(char_id, _master_id, guild_id), do: member_of?(char_id, guild_id)

  defp member_of?(char_id, guild_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{guild_id: ^guild_id}, _pid}} -> true
      _other -> false
    end
  end

  defp buff_member(char_id, instance) do
    for {status_id, val_key} <- @aura_statuses,
        level = Map.get(instance, val_key) || 0,
        level > 0 do
      # Applied from the tick manager, not the member's own session: the
      # explicit notify publishes the member's async stat refresh.
      StatusInterpreter.apply_status(:player, char_id, status_id,
        val1: level,
        duration: @buff_duration,
        owner_refresh: :notify
      )
    end

    :ok
  end
end
