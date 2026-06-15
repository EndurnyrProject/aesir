defmodule Aesir.ZoneServer.Unit.Player.StatusSync do
  @moduledoc """
  Builds and sends character status-parameter packets (SP_*) to a player's
  client.

  Picks `ZC_PAR_CHANGE` or `ZC_LONGPAR_CHANGE` based on the parameter, so the
  rest of the player domain can sync stats without reaching into packet
  routing.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Packets.ZcLongparChange
  alias Aesir.ZoneServer.Packets.ZcParChange
  alias Aesir.ZoneServer.Unit.Player.Stats

  # Params whose values can exceed a 16-bit field and need the wide packet.
  @long_params [
    StatusParams.base_exp(),
    StatusParams.job_exp(),
    StatusParams.next_base_exp(),
    StatusParams.next_job_exp()
  ]

  @doc """
  Builds the status packet for a single parameter/value pair.
  """
  @spec build(integer(), integer()) :: ZcParChange.t() | ZcLongparChange.t()
  def build(param_id, value) when param_id in @long_params do
    %ZcLongparChange{var_id: param_id, value: value}
  end

  def build(param_id, value) do
    %ZcParChange{var_id: param_id, value: value}
  end

  @doc """
  Sends a single status update to the player's connection.
  """
  @spec send_param(pid(), integer(), integer()) :: :ok
  def send_param(connection_pid, param_id, value) do
    send(connection_pid, {:send_packet, build(param_id, value)})
    :ok
  end

  @doc """
  Sends a collection of `{param_id, value}` pairs to the player's connection.
  """
  @spec send_params(pid(), Enumerable.t()) :: :ok
  def send_params(connection_pid, params) do
    Enum.each(params, fn {param_id, value} -> send_param(connection_pid, param_id, value) end)
  end

  @doc """
  Sends the full set of base/derived/combat/progression stats to the client.
  """
  @spec send_stat_updates(pid(), Stats.t()) :: :ok
  def send_stat_updates(connection_pid, stats) do
    send_params(connection_pid, %{
      # Base stats
      StatusParams.str() => stats.base_stats.str,
      StatusParams.agi() => stats.base_stats.agi,
      StatusParams.vit() => stats.base_stats.vit,
      StatusParams.int() => stats.base_stats.int,
      StatusParams.dex() => stats.base_stats.dex,
      StatusParams.luk() => stats.base_stats.luk,

      # Derived stats
      StatusParams.max_hp() => stats.derived_stats.max_hp,
      StatusParams.max_sp() => stats.derived_stats.max_sp,
      StatusParams.hp() => stats.current_state.hp,
      StatusParams.sp() => stats.current_state.sp,
      StatusParams.aspd() => stats.derived_stats.aspd,

      # Combat stats
      StatusParams.hit() => stats.combat_stats.hit,
      StatusParams.flee1() => stats.combat_stats.flee,
      StatusParams.critical() => stats.combat_stats.critical,
      StatusParams.atk1() => stats.combat_stats.atk,
      StatusParams.def1() => stats.combat_stats.def,

      # Progression
      StatusParams.base_level() => stats.progression.base_level,
      StatusParams.job_level() => stats.progression.job_level,
      StatusParams.base_exp() => stats.progression.base_exp,
      StatusParams.job_exp() => stats.progression.job_exp
    })
  end
end
