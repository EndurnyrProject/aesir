defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrAspersio do
  @moduledoc """
  Aspersio (PR_ASPERSIO). Endows a player's weapon with the holy element for 1 minute
  plus 30 s per level, or strikes an undead enemy with a holy magic attack on a
  base of 40 that ignores MDEF, the element table and element cards.

  Renewal and pre-renewal agree: 9-cell range, 14 to 30 SP, one Holy Water, and a
  2 s delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 68,
    name: :pr_aspersio,
    status: :sc_aspersio,
    display_name: "Aspersio",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    ignore_element: true,
    damage_kind: :magic,
    element: :holy,
    range: 9,
    after_cast_delay: List.duplicate(2_000, 5),
    sp_cost: [14, 18, 22, 26, 30],
    item_cost: [%{id: 523, amount: 1}],
    duration: [60_000, 90_000, 120_000, 150_000, 180_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  # The whole target decision is the implementation's, after the requirement is
  # paid: the reference refuses only a non-undead monster there, and it reports
  # that with the animation rather than a cast failure. A target that cannot be
  # resolved at all is already refused before the cost by the interpreter's own
  # target checks.
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    apply_endow(caster, :player, caster_id, caster_id, level, definition)
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    case target_kind(target_id) do
      :player -> apply_endow(caster, :player, caster_id, target_id, level, definition)
      :homunculus -> apply_endow(caster, :homunculus, caster_id, target_id, level, definition)
      :undead_enemy -> damage_undead(caster, target_id, level, definition)
      # A non-undead monster is refused inside the implementation, which only
      # reports the animation: the cast succeeds and its item is consumed.
      :invalid -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp damage_undead(caster, target_id, level, definition) do
    case Combat.execute_magic_attack(caster, target_id,
           skill_id: definition.id,
           skill_level: level,
           element: definition.element,
           base_damage: 40,
           ignore_mdef: true,
           skip_range: true
         ) do
      {:ok, _ref} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp apply_endow(caster, unit_type, caster_id, target_id, level, definition) do
    StatusInterpreter.apply_status(unit_type, target_id, :sc_aspersio,
      val1: level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    )

    {:ok, caster}
  end

  defp undead?(target), do: RaceModifiers.undead_target?(target)

  defp target_kind(target_id) do
    case Combat.resolve_combatant(target_id) do
      {:ok, %{unit_type: :player}} -> :player
      {:ok, %{unit_type: :homunculus}} -> :homunculus
      {:ok, %{unit_type: :mob} = target} -> if undead?(target), do: :undead_enemy, else: :invalid
      {:ok, _target} -> :invalid
      {:error, _reason} = error -> error
    end
  end
end
