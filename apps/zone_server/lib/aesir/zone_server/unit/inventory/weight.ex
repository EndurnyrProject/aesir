defmodule Aesir.ZoneServer.Unit.Inventory.Weight do
  @moduledoc """
  Pure weight calculations for a player's inventory.

  - `current_weight/1` sums `ItemDefinition.weight × amount` over every item in
    the inventory map (equipped and not).
  - `max_weight/1` is the per-job base (`Job.max_weight`) plus `STR × 300` plus
    any passive max-weight bonus (e.g. MC_INCCARRY).

  ## Unit

  Weights are kept in the same raw unit as `ItemDefinition.weight` and
  `Job.max_weight` (the db values), with no `×10` scaling. rAthena scales weight
  by 10 internally for the client; that scaling is applied at the packet layer,
  not here.

  Reads item definitions from `:persistent_term` via `ItemManagement` and job
  data via `JobManagement`; no DB or socket access.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Unit.Player.Stats

  @str_weight_per_point 300

  @type inventory :: %{non_neg_integer() => InventoryItem.t()}

  @doc """
  Total weight of every item in the inventory (equipped and carried alike).
  """
  @spec current_weight(inventory()) :: non_neg_integer()
  def current_weight(inventory) when is_map(inventory) do
    inventory
    |> Map.values()
    |> Enum.reduce(0, fn %InventoryItem{nameid: nameid, amount: amount}, acc ->
      acc + item_weight(nameid) * amount
    end)
  end

  @doc """
  Maximum weight the player can carry: job base plus `STR × 300` plus any
  passive max-weight bonus (e.g. MC_INCCARRY).
  """
  @spec max_weight(Stats.t()) :: non_neg_integer()
  def max_weight(%Stats{} = stats) do
    str = Stats.get_effective_stat(stats, :str)
    passive_bonus = Map.get(stats.modifiers.passive, :max_weight_bonus, 0)

    job_base(stats.progression.job_id) + str * @str_weight_per_point + passive_bonus
  end

  @doc """
  Whether adding `added_weight` would push current weight past the max.
  """
  @spec would_exceed?(inventory(), Stats.t(), integer()) :: boolean()
  def would_exceed?(inventory, %Stats{} = stats, added_weight) do
    current_weight(inventory) + added_weight > max_weight(stats)
  end

  @spec item_weight(integer()) :: non_neg_integer()
  defp item_weight(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{weight: weight}} -> weight
      {:error, :item_not_found} -> 0
    end
  end

  @spec job_base(non_neg_integer()) :: non_neg_integer()
  defp job_base(job_id) do
    case JobManagement.get_job_by_id(job_id) do
      {:ok, %{max_weight: max_weight}} -> max_weight
      {:error, _reason} -> 0
    end
  end
end
