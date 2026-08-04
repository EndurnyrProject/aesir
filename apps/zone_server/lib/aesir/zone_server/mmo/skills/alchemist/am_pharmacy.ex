defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPharmacy do
  @moduledoc """
  Pharmacy (AM_PHARMACY) opens a menu of available recipes and brews its selection.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 228,
    name: :am_pharmacy,
    display_name: "Pharmacy",
    max_level: 10,
    target_type: :self,
    sp_cost: List.duplicate(5, 10),
    item_cost: [%{id: 7134, amount: 1}]

  @behaviour Aesir.ZoneServer.Mmo.Skill.Active
  @behaviour Aesir.ZoneServer.Mmo.Skill.Menu

  alias Aesir.ZoneServer.Mmo.Homunculus.Stats, as: HomunculusStats
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @pharmacy_skill_id 228

  @doc "Stages the recipes available at the cast Pharmacy level."
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :no_materials}
  @impl Aesir.ZoneServer.Mmo.Skill.Active
  def cast(%PlayerState{} = caster, :self, level, _definition) do
    case Recipes.offerable(@pharmacy_skill_id, level) do
      [] ->
        {:error, :no_materials}

      recipes ->
        offer = %{
          skill_id: @pharmacy_skill_id,
          kind: :ITEMS,
          entry_ids: Enum.map(recipes, & &1.product_id),
          level: level
        }

        {:ok, %{caster | pending_menu_offer: offer}}
    end
  end

  @doc "Brews the selected Pharmacy recipe without forge catalysts."
  @spec on_menu_reply(
          PlayerState.t(),
          %{id: non_neg_integer(), extras: [non_neg_integer()]},
          pos_integer()
        ) :: {:ok, PlayerState.t()} | {:error, atom()}
  @impl Aesir.ZoneServer.Mmo.Skill.Menu
  def on_menu_reply(%PlayerState{} = caster, selection, level) do
    on_menu_reply(caster, selection, level, %{homunculus: nil})
  end

  @doc "Brews the selected Pharmacy recipe with session-owned Homunculus context."
  @spec on_menu_reply(
          PlayerState.t(),
          %{id: non_neg_integer(), extras: [non_neg_integer()]},
          pos_integer(),
          %{required(:homunculus) => HomunculusState.t() | nil}
        ) :: {:ok, PlayerState.t()} | {:error, atom()}
  @impl Aesir.ZoneServer.Mmo.Skill.Menu
  def on_menu_reply(
        %PlayerState{} = caster,
        %{id: product_id},
        _level,
        %{homunculus: homunculus}
      ) do
    case Enum.find(
           Recipes.all(),
           &(&1.product_id == product_id and &1.skill_id == @pharmacy_skill_id)
         ) do
      nil ->
        {:error, :invalid_recipe}

      recipe ->
        Forge.run(caster, recipe, [], active_instruction_change_rank(homunculus))
    end
  end

  defp active_instruction_change_rank(%HomunculusState{} = homunculus) do
    if HomunculusState.living?(homunculus),
      do: HomunculusStats.instruction_change_rank(homunculus),
      else: 0
  end

  defp active_instruction_change_rank(nil), do: 0
end
