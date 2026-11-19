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
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Mechanics
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
    window = status_window(stats)

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
      # The wire value is unsigned, so an ASPD below 0 shows as 0.
      StatusParams.aspd() => max(stats.derived_stats.aspd, 0),

      # Combat stats
      StatusParams.hit() => stats.combat_stats.hit,
      StatusParams.flee1() => stats.combat_stats.flee,
      # Perfect dodge is held in tenths; the window shows whole points.
      StatusParams.flee2() => div(stats.combat_stats.perfect_dodge, 10),
      StatusParams.critical() => stats.combat_stats.critical,
      StatusParams.atk1() => window.atk1,
      StatusParams.atk2() => window.atk2,
      StatusParams.matk1() => window.matk1,
      StatusParams.matk2() => window.matk2,
      StatusParams.def1() => window.def1,
      StatusParams.def2() => window.def2,
      StatusParams.mdef1() => window.mdef1,
      StatusParams.mdef2() => window.mdef2,

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

  # The two-part ATK, MATK, DEF and MDEF values of the active mode's status
  # window. The wire value is unsigned, so a negative part shows as 0.
  defp status_window(%Stats{} = stats) do
    combat = stats.combat_stats
    attack = combat.physical_attack
    equipment = stats.modifiers.equipment
    wmatk_min = Map.get(equipment, :wmatk_min, 0)
    wmatk_max = Map.get(equipment, :wmatk_max, 0)
    {hard_def, soft_def} = DamageInputs.status_window_defense(stats)
    {hard_mdef, soft_mdef} = DamageInputs.status_window_magic_defense(stats)
    right = hand(stats.right_hand, Map.get(attack, :bare_right_atk, 0))
    left = hand(stats.left_hand, Map.get(attack, :bare_left_atk, 0))

    %{
      status_atk: attack.status_atk,
      hilt_binding_atk: Map.get(attack, :hilt_binding_atk, 0),
      bonus_atk: attack.flat_atk,
      right_atk: right.atk,
      right_refine_atk: right.refine_atk,
      right_level: right.level,
      left_atk: left.atk,
      left_refine_atk: left.refine_atk,
      left_level: left.level,
      status_watk: Stats.get_status_modifier(stats, :watk),
      level4_watk: Stats.get_status_modifier(stats, :level4_watk),
      hard_def: hard_def,
      soft_def: soft_def,
      hard_mdef: hard_mdef,
      soft_mdef: soft_mdef,
      vit: Stats.get_effective_stat(stats, :vit),
      # Heal MATK is the status formula plus the weapon band's lower end.
      status_matk: combat.heal_matk_min - wmatk_min,
      # The band is symmetric around weapon MATK with refine.
      weapon_matk: div(wmatk_min + wmatk_max, 2),
      flat_matk:
        Stats.get_equipment_modifier(stats, :matk) + Stats.get_status_modifier(stats, :matk),
      matk_min: combat.matk_min,
      matk_max: combat.matk_max,
      matk_amp_rate: Stats.get_status_modifier(stats, :base_matk_rate)
    }
    |> Mechanics.status_window().values()
    |> Map.new(fn {param, value} -> {param, max(value, 0)} end)
  end

  defp hand(nil, bare_atk), do: %{atk: bare_atk, refine_atk: 0, level: 0}

  defp hand(hand, _bare_atk),
    do: %{atk: hand.base_atk, refine_atk: hand.refine_atk, level: hand.weapon_level}
end
