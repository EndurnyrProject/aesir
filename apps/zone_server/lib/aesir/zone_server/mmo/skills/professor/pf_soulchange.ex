defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulchange do
  @moduledoc """
  Soul Exhale (PF_SOULCHANGE). Exchanges SP with a party or guild member, or
  draws SP from a monster.

  On a player, the Professor and the target swap their SP. Renewal halves both
  pools first, and a target readied for Asura Strike receives its own SP back
  instead. In both modes a target under a no-recovery state keeps its own SP.
  The 5 SP cost is paid before the exchange.
  On a monster, the Professor regains 3% of their max SP; each monster yields
  this only once.

  Both modes: 5 SP, 9 cells. Renewal: 3 s fixed cast. Pre-renewal: 3 s cast and
  a 5 s after-cast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 374,
    name: :pf_soulchange,
    display_name: "Soul Exhale",
    max_level: 1,
    target_type: :target_any,
    damage_type: :no_damage,
    range: 9,
    sp_cost: [5],
    cast_time: [renewal: [], pre_renewal: [3_000]],
    fixed_cast_time: [renewal: [3_000], pre_renewal: []],
    after_cast_delay: [renewal: [], pre_renewal: [5_000]]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%PlayerState{character_id: id}, {:unit, id}, _level, _definition),
    do: {:error, :invalid_target}

  def validate(%PlayerState{} = caster, {:unit, target_id}, _level, _definition) do
    case resolve(target_id) do
      {:ok, :mob, mob, _pid} ->
        Targeting.validate_enemy(caster, mob)

      {:ok, :player, target, _pid} ->
        if comrade?(caster, target), do: :ok, else: {:error, :invalid_target}

      error ->
        error
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @doc """
  Requires the resolved SP to start but spends none up front: `cast/4` pays it
  before the exchange, so the swapped amount is the SP left after the cost.
  """
  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(caster, _target, level, definition) do
    caster
    |> Cost.from_definition(definition, level, sp: 0)
    |> Map.put(:sp_requirement, Cost.resolve_sp(caster, definition, level))
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, {:unit, target_id}, level, definition) do
    caster = PlayerCaster.deduct_sp(caster, Cost.resolve_sp(caster, definition, level))

    case resolve(target_id) do
      {:ok, :mob, _mob, _pid} -> drain_monster(caster, target_id)
      {:ok, :player, target, pid} -> {:ok, swap(caster, target, pid)}
      error -> error
    end
  end

  defp drain_monster(%PlayerState{character_id: id, stats: stats} = caster, mob_id) do
    case StatusInterpreter.apply_status(:mob, mob_id, :sc_soulchange_marker, caster_id: id) do
      :ok ->
        {:ok, put_sp(caster, stats.current_state.sp + div(stats.derived_stats.max_sp * 3, 100))}

      _marked ->
        {:error, :already_exchanged}
    end
  end

  defp swap(caster, %PlayerState{character_id: target_id} = target, pid) do
    {to_target, to_caster} =
      exchanged(caster.stats.current_state.sp, target.stats.current_state.sp, target_id)

    PlayerSession.set_vitals(pid, sp: to_target)
    put_sp(caster, to_caster)
  end

  # Returns {SP the target ends with, SP the caster ends with}.
  defp exchanged(caster_sp, target_sp, target_id) do
    {to_target, to_caster} =
      case GameMode.mode() do
        :renewal -> renewal_exchange(caster_sp, target_sp, target_id)
        :pre_renewal -> {caster_sp, target_sp}
      end

    if StatusStorage.has_status?(:player, target_id, :sc_norecover_state),
      do: {target_sp, to_caster},
      else: {to_target, to_caster}
  end

  defp renewal_exchange(caster_sp, target_sp, target_id) do
    if StatusStorage.has_status?(:player, target_id, :sc_extremityfist),
      do: {target_sp, div(target_sp, 2)},
      else: {div(caster_sp, 2), div(target_sp, 2)}
  end

  defp comrade?(caster, target) do
    shared?(caster.party_id, target.party_id) or shared?(caster.guild_id, target.guild_id)
  end

  defp shared?(id, id) when is_integer(id) and id > 0, do: true
  defp shared?(_caster_id, _target_id), do: false

  defp put_sp(%PlayerState{stats: stats} = caster, sp) do
    current = %{stats.current_state | sp: min(max(sp, 0), stats.derived_stats.max_sp)}
    %{caster | stats: %{stats | current_state: current}}
  end

  # Mobs first: a player and a mob never share an id.
  defp resolve(target_id) do
    with {:error, :not_found} <- unit(:mob, target_id),
         {:error, :not_found} <- unit(:player, target_id) do
      {:error, :target_not_found}
    end
  end

  defp unit(type, id) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, pid}} -> {:ok, type, state, pid}
      {:error, :not_found} -> {:error, :not_found}
    end
  end
end
