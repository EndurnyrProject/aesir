defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaFrostweapon do
  @moduledoc """
  Frost Weapon (SA_FROSTWEAPON). Endows an ally's weapon with the water element; a bare-handed
  target fails before any cost is charged.

  Renewal: always succeeds, 10 minutes plus 5 per level, a 1 s cast plus 1 s fixed,
  and one elemental point catalyst. Pre-renewal: succeeds 60% plus 10% per level of
  the time (a failed cast still spends the SP and catalyst; the source also
  unequips the target's weapon, which Aesir does not model), lasts 20 minutes at
  levels 1 to 4 and 30 at level 5, casts in 3 s, and burns one raw elemental ore.
  Both cost 40 SP at 9 cells.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 281,
    name: :sa_frostweapon,
    status: :sc_waterweapon,
    display_name: "Frost Weapon",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :water,
    range: 9,
    cast_time: [renewal: List.duplicate(1000, 5), pre_renewal: List.duplicate(3000, 5)],
    fixed_cast_time: [renewal: List.duplicate(1000, 5), pre_renewal: []],
    sp_cost: List.duplicate(40, 5),
    item_cost: [renewal: [%{id: 6361, amount: 1}], pre_renewal: [%{id: 991, amount: 1}]],
    duration: [
      renewal: [600_000, 900_000, 1_200_000, 1_500_000, 1_800_000],
      pre_renewal: [1_200_000, 1_200_000, 1_200_000, 1_200_000, 1_800_000]
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Sage.Endow
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: :ok
  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), atom()} | {:error, atom()}
  def cast(caster, target, level, definition),
    do: Endow.cast(caster, target, level, definition, :sc_waterweapon)
end
