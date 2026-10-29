defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrFullprotection do
  @moduledoc """
  Full Protection (CR_FULLPROTECTION).

  Coats every piece a player target wears (weapon, shield, armor, head top, with
  the Chemical Protection hand rules) for 2 minutes per level, starting each
  piece's Chemical Protection status. A target wearing none of them, or a target
  that is not a player, makes the cast fail with the Coating Bottle spared and
  the SP spent.

  Renewal: a 1 s fixed cast and a 0.5 s delay. Pre-renewal: a 2 s cast. Both
  cost 40 SP and one Coating Bottle. No monster casts it.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 479,
    name: :cr_fullprotection,
    display_name: "Full Protection",
    max_level: 5,
    target_type: :target_ally,
    range: 1,
    sp_cost: List.duplicate(40, 5),
    item_cost: [%{id: 7139, amount: 1}],
    duration: [120_000, 240_000, 360_000, 480_000, 600_000],
    cast_time: [renewal: [], pre_renewal: List.duplicate(2_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.ChemicalProtection
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @statuses %{
    weapon: :sc_cp_weapon,
    shield: :sc_cp_shield,
    armor: :sc_cp_armor,
    head_top: :sc_cp_helm
  }

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :invalid_target, :spare_items}
  def cast(%PlayerState{} = caster, target, level, definition) do
    target_id = Active.resolve_target_id(caster, target)

    case ChemicalProtection.worn_slots(target_id) do
      [] ->
        {:failed, caster, :invalid_target, :spare_items}

      slots ->
        Enum.each(slots, fn slot ->
          StatusInterpreter.apply_status(:player, target_id, Map.fetch!(@statuses, slot),
            val1: level,
            caster_id: caster.character_id,
            duration: Enum.at(definition.duration, level - 1)
          )
        end)

        {:ok, caster}
    end
  end
end
