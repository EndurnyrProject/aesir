defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombatTarget do
  @moduledoc """
  Resolves the live trap owner relationship used by opt-in misc splash attacks.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @spec targetable?(Ref.t()) :: boolean()
  def targetable?({:skill_unit, _cell_id} = target_ref) do
    match?({:ok, _cell, _social_root}, resolve(target_ref))
  end

  def targetable?(_target_ref), do: false

  @spec to_combatant(Cell.t()) :: {:ok, map()} | {:error, :target_not_found}
  def to_combatant(%Cell{} = cell) do
    with {:ok, ^cell, social_root} <- resolve({:skill_unit, cell.cell_id}) do
      {:ok, cell |> CombatTarget.to_combatant() |> Map.put(:social_root, social_root)}
    end
  end

  defp resolve({:skill_unit, _cell_id} = target_ref) do
    with {:ok, _manager_pid, %Cell{group_id: group_id} = cell, :skill_unit} <-
           CombatTarget.resolve(target_ref),
         %Group{state: %{trap: %TrapState{}}} = group <- Storage.get(group_id),
         {:ok, social_root} <- owner_social_root(group) do
      {:ok, cell, social_root}
    else
      _ -> {:error, :target_not_found}
    end
  end

  defp owner_social_root(%Group{caster_type: caster_type, caster_id: caster_id}) do
    with true <- Ref.valid?({caster_type, caster_id}),
         {:ok, {module, state, _pid}} <- UnitRegistry.get_unit(caster_type, caster_id),
         true <- Unit.living?(state) do
      {:ok, state |> module.to_combatant() |> Relationship.social_root()}
    else
      _ -> {:error, :target_not_found}
    end
  end
end
