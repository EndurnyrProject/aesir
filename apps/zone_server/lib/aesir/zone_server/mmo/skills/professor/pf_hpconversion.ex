defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfHpconversion do
  @moduledoc """
  Indulge (PF_HPCONVERSION). Pays a tenth of max HP to regain that amount of SP
  per level, clamped at max SP. Refused when HP is not above the cost or SP is
  already full.

  Both modes: 1 to 5 SP, instant. Renewal: 0.5 s after-cast delay. Pre-renewal:
  1 to 1.8 s after-cast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 373,
    name: :pf_hpconversion,
    display_name: "Indulge",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    sp_cost: [1, 2, 3, 4, 5],
    hp_cost_rate: List.duplicate(10, 5),
    after_cast_delay: [
      renewal: List.duplicate(500, 5),
      pre_renewal: [1_000, 1_200, 1_400, 1_600, 1_800]
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :sp_full}
  def validate(
        %PlayerState{stats: %{current_state: %{sp: sp}, derived_stats: %{max_sp: sp}}},
        _target,
        _level,
        _definition
      ),
      do: {:error, :sp_full}

  def validate(_caster, _target, _level, _definition), do: :ok

  @doc """
  Requires the resolved SP and charges the HP up front, but spends no SP there:
  `cast/4` pays it before converting, so the SP cap applies after the cost.
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
          {:ok, PlayerState.t()}
  def cast(%PlayerState{} = caster, :self, level, definition) do
    %PlayerState{stats: stats} =
      caster = PlayerCaster.deduct_sp(caster, Cost.resolve_sp(caster, definition, level))

    current = stats.current_state
    gain = div(stats.derived_stats.max_hp, 10) * level
    sp = min(current.sp + gain, stats.derived_stats.max_sp)
    {:ok, %{caster | stats: %{stats | current_state: %{current | sp: sp}}}}
  end
end
