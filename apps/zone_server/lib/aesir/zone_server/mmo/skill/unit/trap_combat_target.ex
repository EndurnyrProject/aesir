defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombatTarget do
  @moduledoc """
  Resolves live traps for attacks that explicitly admit skill-unit targets.

  An eligible trap is an enemy target regardless of who placed it. Its owner's
  party, guild or continued presence does not protect it from such an attack.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit.Ref

  @doc "Whether this reference resolves to a currently targetable trap cell."
  @spec targetable?(Ref.t()) :: boolean()
  def targetable?({:skill_unit, _cell_id} = target_ref), do: match?({:ok, _}, resolve(target_ref))
  def targetable?(_target_ref), do: false

  @doc "Returns the trap's defender without inheriting an owner's friendly relationship."
  @spec to_combatant(Cell.t()) :: {:ok, map()} | {:error, :target_not_found}
  def to_combatant(%Cell{} = cell) do
    with {:ok, ^cell} <- resolve({:skill_unit, cell.cell_id}),
         do: {:ok, CombatTarget.to_combatant(cell)}
  end

  defp resolve(target_ref) do
    with {:ok, _, %Cell{group_id: group_id} = cell, :skill_unit} <-
           CombatTarget.resolve(target_ref),
         %Group{state: %{trap: %TrapState{}}} <- Storage.get(group_id) do
      {:ok, cell}
    else
      _unavailable -> {:error, :target_not_found}
    end
  end
end
