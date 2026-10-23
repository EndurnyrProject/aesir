defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaLightningloader do
  @moduledoc """
  Lightning Loader (SA_LIGHTNINGLOADER). Endows an ally's weapon with the wind element; a bare-handed
  target fails the cast after its cost is charged, and another player's
  Homunculus is refused silently before the cast begins.

  Renewal: always succeeds, 10 minutes plus 5 per level, a 1 s cast plus 1 s fixed,
  and one elemental point catalyst. Pre-renewal: succeeds 60% plus 10% per level of
  the time (a failed cast still spends the SP and catalyst; the source also
  unequips the target's weapon, which Aesir does not model), lasts 20 minutes at
  levels 1 to 4 and 30 at level 5, casts in 3 s, and burns one raw elemental ore.
  Both cost 40 SP at 9 cells.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 282,
    name: :sa_lightningloader,
    status: :sc_windweapon,
    display_name: "Lightning Loader",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :wind,
    range: 9,
    cast_time: [renewal: List.duplicate(1000, 5), pre_renewal: List.duplicate(3000, 5)],
    fixed_cast_time: [renewal: List.duplicate(1000, 5), pre_renewal: []],
    sp_cost: List.duplicate(40, 5),
    item_cost: [renewal: [%{id: 6362, amount: 1}], pre_renewal: [%{id: 992, amount: 1}]],
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
  @spec skilluse_check(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :target_restricted}
  def skilluse_check(caster, target, _level, _definition),
    do: Endow.homunculus_support(caster, target)

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), atom()} | {:error, atom()}
  def cast(caster, target, level, definition),
    do: Endow.cast(caster, target, level, definition, :sc_windweapon)
end
