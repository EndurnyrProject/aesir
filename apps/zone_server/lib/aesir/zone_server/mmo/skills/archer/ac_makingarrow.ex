defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcMakingarrow do
  @moduledoc """
  Arrow Crafting (AC_MAKINGARROW). Archer quest skill: converts 1 material item
  from the inventory into a fixed set of arrows.

  rAthena (`db/re/skill_db.yml` id 147): self-targeted, no damage, SP 10,
  MaxLevel 1. The recipes live in `create_arrow_db.yml` (imported to
  `priv/db/arrows.yml`, served by `ItemManagement.ArrowCrafting`);
  `skill_arrow_create` consumes exactly 1 source item and produces every
  `Make` entry of its recipe.

  rAthena presents the material list through a dedicated client packet
  (`clif_arrow_create_list`). Aesir has no such wire message, so the cast
  stages `pending_interaction` on the returned `PlayerState` and the skill
  handler opens a `Script.Interaction` dialog (this module's `on_talk/1`)
  listing the craftable materials instead — same window the NPC scripts use.
  The `State: Recover_Weight_Rate` (not-overweight) cast requirement is not
  enforced; the interpreter has no weight-state gate yet.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 147,
    name: :ac_makingarrow,
    display_name: "Arrow Crafting",
    max_level: 1,
    target_type: :self,
    sp_cost: [10],
    quest_skill: true,
    quest_owner_job: :archer

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting
  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting.Recipe
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(caster, :self, _level, _definition) do
    {:ok, %{caster | pending_interaction: __MODULE__}}
  end

  @doc """
  The crafting dialog run by the staged `Script.Interaction`: lists every
  recipe whose source item the player holds, crafts the selected one, and
  closes. Cancel/ESC ends the interaction inside `select/2`.
  """
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(%Ctx{} = ctx) do
    case craftable(ctx) do
      [] ->
        ctx
        |> mes("You have no materials that can be crafted into arrows.")
        |> close()

      recipes ->
        offer(ctx, recipes)
    end
  end

  @spec craftable(Ctx.t()) :: [Recipe.t()]
  defp craftable(ctx) do
    Enum.filter(ArrowCrafting.all(), fn %Recipe{source_id: source_id} ->
      count_item(ctx, source_id) > 0
    end)
  end

  @spec offer(Ctx.t(), [Recipe.t()]) :: Ctx.t()
  defp offer(ctx, recipes) do
    {ctx, choice} =
      ctx
      |> mes("Which material would you like to craft into arrows?")
      |> select(Enum.map(recipes, &item_name(&1.source_id)))

    case fetch_recipe(recipes, choice) do
      {:ok, recipe} -> craft(ctx, recipe)
      :error -> close(ctx)
    end
  end

  @spec fetch_recipe([Recipe.t()], non_neg_integer()) :: {:ok, Recipe.t()} | :error
  defp fetch_recipe(recipes, choice) when choice >= 1 and choice <= length(recipes) do
    {:ok, Enum.at(recipes, choice - 1)}
  end

  defp fetch_recipe(_recipes, _choice), do: :error

  @spec craft(Ctx.t(), Recipe.t()) :: Ctx.t()
  defp craft(ctx, %Recipe{source_id: source_id, makes: makes}) do
    ctx = delitem(ctx, source_id, 1)

    ctx =
      Enum.reduce(makes, ctx, fn %{item_id: item_id, amount: amount}, acc ->
        give_item(acc, item_id, amount)
      end)

    case ctx.status do
      :ok ->
        ctx
        |> mes("You craft #{describe(makes)}.")
        |> close()

      {:error, _reason} ->
        ctx
        |> mes("You fail to craft the arrows.")
        |> close()
    end
  end

  @spec describe([%{item_id: integer(), amount: pos_integer()}]) :: String.t()
  defp describe(makes) do
    Enum.map_join(makes, ", ", fn %{item_id: item_id, amount: amount} ->
      "#{amount}x #{item_name(item_id)}"
    end)
  end

  # Every id in arrows.yml is resolved against the item catalog at import time,
  # so a missing definition here is a data bug worth crashing the dialog over.
  @spec item_name(integer()) :: String.t()
  defp item_name(item_id) do
    {:ok, %{name: name}} = ItemManagement.get_item_by_id(item_id)
    name
  end
end
