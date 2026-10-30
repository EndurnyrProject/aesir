defmodule Aesir.ZoneServer.Mmo.Fame do
  @moduledoc "Pure production fame rules and session-owned award staging."

  import Bitwise

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @pharmacy_skills [228, 496, 497, 498]
  @potion_skills @pharmacy_skills ++ [407, 2025]

  @typedoc "The two production ranking professions."
  @type category :: :blacksmith | :alchemist

  @typedoc "A requested award and its capped total, queued in production order."
  @type award_event :: %{
          category: category(),
          awarded_points: pos_integer(),
          total_fame: non_neg_integer()
        }

  @doc "Returns the production profession for a job, or nil for an ineligible job."
  @spec category(integer()) :: category() | nil
  def category(job_id) do
    with mapid when mapid >= 0 <- JobMapid.from_job(job_id),
         {:ok, mask} <- JobMapid.constant("EAJ_UPPERMASK"),
         {:ok, blacksmith} <- JobMapid.constant("EAJ_BLACKSMITH"),
         {:ok, alchemist} <- JobMapid.constant("EAJ_ALCHEMIST") do
      case band(mapid, mask) do
        ^blacksmith -> :blacksmith
        ^alchemist -> :alchemist
        _other -> nil
      end
    else
      _unknown -> nil
    end
  end

  @doc "Evolves the transient potion streak and returns the points for one actual outcome."
  @spec potion_result(non_neg_integer(), pos_integer(), pos_integer(), boolean()) ::
          {non_neg_integer(), non_neg_integer()}
  def potion_result(_counter, skill_id, _product_id, false) when skill_id in @potion_skills,
    do: {0, 0}

  def potion_result(counter, skill_id, product_id, true)
      when skill_id in @pharmacy_skills and product_id in 545..547 do
    case counter + 1 do
      3 -> {3, 1}
      5 -> {5, 3}
      7 -> {7, 10}
      10 -> {0, 50}
      next -> {next, 0}
    end
  end

  def potion_result(counter, _skill_id, _product_id, _success?), do: {counter, 0}

  @doc "Awards ten points for a level-three-or-higher weapon with three resolved additions."
  @spec forge_points(non_neg_integer(), non_neg_integer(), atom() | nil) :: non_neg_integer()
  def forge_points(level, crumbs, element) when level >= 3 do
    additions = crumbs + if(element in [nil, :neutral], do: 0, else: 1)
    if additions >= 3, do: 10, else: 0
  end

  def forge_points(_level, _crumbs, _element), do: 0

  @doc "Returns the award for script refinement of the maker's own forged weapon to ten."
  @spec refine_points(InventoryItem.t(), ItemDefinition.t(), pos_integer(), non_neg_integer()) ::
          non_neg_integer()
  def refine_points(item, %ItemDefinition{type: :weapon, weapon_level: level}, character_id, 10) do
    case ItemCraft.from_map(item.craft) do
      {:ok, %ItemCraft{kind: :forged, creator_char_id: ^character_id}} -> refine_award(level)
      _other -> 0
    end
  end

  def refine_points(_item, _definition, _character_id, _refine), do: 0

  defp refine_award(1), do: 1
  defp refine_award(2), do: 25
  defp refine_award(3), do: 1_000
  defp refine_award(_level), do: 0

  @doc "Stages a positive eligible award, retaining the requested amount even at the fame cap."
  @spec award(PlayerState.t(), non_neg_integer()) :: PlayerState.t()
  def award(player, 0), do: player

  def award(%PlayerState{stats: %{progression: %{job_id: job_id}}} = player, points)
      when points > 0 do
    case category(job_id) do
      nil -> player
      category -> stage_award(player, category, points)
    end
  end

  defp stage_award(player, category, points) do
    total = min(player.fame + points, 1_000_000_000)
    event = %{category: category, awarded_points: points, total_fame: total}
    %{player | fame: total, pending_fame_awards: player.pending_fame_awards ++ [event]}
  end
end
