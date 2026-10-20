defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.ChemicalProtection do
  @moduledoc """
  Shared cast for the four Chemical Protection skills.

  The reference refuses a target that is not a player, or a player missing the
  protected piece, from inside the implementation and sets
  `SKILL_NOCONSUME_REQ`: the failure is reported and the Coating Bottle is
  spared. A refused status start is not a cast failure.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "The piece a Chemical Protection skill coats."
  @type slot :: :armor | :head_top | :shield | :weapon

  @doc "Applies `status` to a player target wearing `slot`, sparing the bottle otherwise."
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t(), atom(), slot()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), atom(), :spare_items}
  def cast(
        %PlayerState{character_id: caster_id} = caster,
        target,
        level,
        definition,
        status,
        slot
      ) do
    target_id = Active.resolve_target_id(caster, target)

    if wearing?(target_id, slot) do
      StatusInterpreter.apply_status(:player, target_id, status,
        val1: level,
        caster_id: caster_id,
        duration: Enum.at(definition.duration, level - 1)
      )

      {:ok, caster}
    else
      {:failed, caster, :invalid_target, :spare_items}
    end
  end

  defp wearing?(target_id, slot) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, %PlayerState{stats: %{equipment: equipment}}, _pid}} ->
        worn?(equipment, slot)

      _not_a_player ->
        false
    end
  end

  defp worn?(equipment, :armor), do: equipment.armor != nil
  defp worn?(equipment, :head_top), do: equipment.head_top != nil
  defp worn?(equipment, :shield), do: PlayerStats.shield?(equipment)

  defp worn?(equipment, :weapon),
    do: equipment.right_hand != nil or equipment.left_hand != nil
end
