defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfHpconversion do
  @moduledoc """
  Indulge (PF_HPCONVERSION). After its SP is spent, pays a tenth of max HP to
  regain that amount of SP per level, clamped at max SP. Refused when SP is
  already full; with HP not above the charge the SP is spent and nothing else
  happens.

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
    cost_before_effect: true,
    after_cast_delay: [
      renewal: List.duplicate(500, 5),
      pre_renewal: [1_000, 1_200, 1_400, 1_600, 1_800]
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
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

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{} = caster, :self, level, _definition), do: convert(caster, level)

  defp convert(%PlayerState{stats: stats} = caster, level) do
    current = stats.current_state
    charge = div(stats.derived_stats.max_hp, 10)

    if current.hp > charge do
      sp = min(current.sp + charge * level, stats.derived_stats.max_sp)
      current = %{current | hp: current.hp - charge, sp: sp}
      {:ok, %{caster | stats: %{stats | current_state: current}}}
    else
      {:ok, caster}
    end
  end
end
