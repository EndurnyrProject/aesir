defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.ForgeSkill do
  @moduledoc """
  Shared menu and production flow for the Blacksmith forge and refine skills.

  The forging chance is 20 per job level plus 10 per DEX and LUK plus a random 10
  to 1000, plus 40, 20, or 10% by weapon level, 5% per smithing level, 1% per
  Weaponry Research level, 1% per Oridecon Research level for level 3 weapons,
  minus 25% for an elemental stone and 15% per Star Crumb, plus the anvil bonus.
  Renewal and pre-renewal agree.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @craft_skill_ids [94, 95, 96] ++ Enum.to_list(98..104)

  @doc "Stages the products available at the cast skill level."
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :no_materials}
  def cast(%PlayerState{} = caster, :self, level, %Definition{id: skill_id}) do
    case Recipes.offerable(skill_id, level) do
      [] ->
        {:error, :no_materials}

      recipes ->
        offer = %{
          skill_id: skill_id,
          kind: :ITEMS,
          entry_ids: Enum.map(recipes, & &1.product_id),
          level: level
        }

        {:ok, %{caster | pending_menu_offer: offer}}
    end
  end

  @doc "Runs the production recipe selected from a forge or refine menu."
  @spec on_menu_reply(
          PlayerState.t(),
          %{id: non_neg_integer(), extras: [non_neg_integer()]},
          pos_integer()
        ) :: {:ok, PlayerState.t()} | {:error, atom()}
  def on_menu_reply(%PlayerState{} = caster, %{id: product_id, extras: extras}, _level) do
    recipe =
      Enum.find(Recipes.all(), fn recipe ->
        recipe.product_id == product_id and recipe.skill_id in @craft_skill_ids
      end)

    Forge.run(caster, recipe, extras)
  end
end
