defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCpWeapon do
  @moduledoc """
  Chemical Protection Weapon (AM_CP_WEAPON).

  Both modes coat the piece for 2 minutes per level with a Coating Bottle.
  Renewal: a 2 s fixed cast and a 0.5 s delay. Pre-renewal: a 2 s cast.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 234,
    name: :am_cp_weapon,
    status: :sc_cp_weapon,
    display_name: "Chemical Protection Weapon",
    max_level: 5,
    target_type: :target_ally,
    range: 1,
    sp_cost: List.duplicate(30, 5),
    item_cost: [%{id: 7139, amount: 1}],
    duration: [120_000, 240_000, 360_000, 480_000, 600_000],
    cast_time: [renewal: [], pre_renewal: List.duplicate(2_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(2_000, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.ChemicalProtection
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
          | {:failed, PlayerState.t(), atom(), :spare_items}
  def cast(caster, target, level, definition),
    do: ChemicalProtection.cast(caster, target, level, definition, :sc_cp_weapon, :weapon)
end
