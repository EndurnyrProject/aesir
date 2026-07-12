defmodule Aesir.ZoneServer.Unit.Player.StatusSync do
  @moduledoc """
  Builds and sends character status-parameter (SP_*) updates to a player's
  client.

  Emits a single `Aesir.Net.ParamChange` per parameter, collapsing the legacy
  `ZC_PAR_CHANGE`/`ZC_LONGPAR_CHANGE` split: the proto `value` is a `uint64`, so
  it carries both the 32-bit and the wide (base/job exp, zeny) parameters without
  truncation. The rest of the player domain syncs stats without reaching into
  packet routing.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Stats

  @doc """
  Builds the `ParamChange` message for a single parameter/value pair.
  """
  @spec build(integer(), integer()) :: ParamChange.t()
  def build(param_id, value) do
    %ParamChange{var_id: param_id, value: value}
  end

  @doc """
  Sends a single status update to the player's connection.
  """
  @spec send_param(pid(), integer(), integer()) :: :ok
  def send_param(connection_pid, param_id, value) do
    MessageRouter.send_to(connection_pid, build(param_id, value))
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
      StatusParams.job_exp() => stats.progression.job_exp,

      # Trait base stats
      StatusParams.pow() => stats.base_stats.pow,
      StatusParams.sta() => stats.base_stats.sta,
      StatusParams.wis() => stats.base_stats.wis,
      StatusParams.spl() => stats.base_stats.spl,
      StatusParams.con() => stats.base_stats.con,
      StatusParams.crt() => stats.base_stats.crt,

      # Derived combat stats
      StatusParams.patk() => stats.combat_stats.patk,
      StatusParams.smatk() => stats.combat_stats.smatk,
      StatusParams.res() => stats.combat_stats.res,
      StatusParams.mres() => stats.combat_stats.mres,
      StatusParams.hplus() => stats.combat_stats.hplus,
      StatusParams.crate() => stats.combat_stats.crate,

      # Trait progression / AP
      StatusParams.trait_point() => stats.progression.trait_point,
      StatusParams.ap() => stats.current_state.ap,
      StatusParams.max_ap() => stats.derived_stats.max_ap
    })
  end
end
