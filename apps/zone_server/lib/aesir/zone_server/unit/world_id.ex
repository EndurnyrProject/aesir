defmodule Aesir.ZoneServer.Unit.WorldId do
  @moduledoc """
  Allocates transient world IDs that do not collide with registered units.
  """

  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Allocates an unused ID from the supplied ascending range."
  @spec allocate(Range.t()) :: {:ok, integer()} | {:error, :exhausted}
  def allocate(min_id..max_id//1) when min_id <= max_id do
    candidate_count = max_id - min_id + 1
    start_id = min_id + :rand.uniform(candidate_count) - 1
    find_unused_id(start_id, min_id, max_id, candidate_count)
  end

  @doc "Atomically claims an unused ID from the supplied ascending range."
  @spec allocate(Range.t(), UnitRegistry.unit_type()) ::
          {:ok, integer()} | {:error, :exhausted}
  def allocate(min_id..max_id//1, unit_type) when min_id <= max_id do
    candidate_count = max_id - min_id + 1
    start_id = min_id + :rand.uniform(candidate_count) - 1
    claim_unused_id(start_id, min_id, max_id, candidate_count, unit_type)
  end

  defp find_unused_id(_id, _min_id, _max_id, 0), do: {:error, :exhausted}

  defp find_unused_id(id, min_id, max_id, remaining) do
    if UnitRegistry.unit_id_exists?(id) do
      find_unused_id(next_id(id, min_id, max_id), min_id, max_id, remaining - 1)
    else
      {:ok, id}
    end
  end

  defp claim_unused_id(_id, _min_id, _max_id, 0, _unit_type), do: {:error, :exhausted}

  defp claim_unused_id(id, min_id, max_id, remaining, unit_type) do
    if UnitRegistry.claim_unit_id(id, unit_type) do
      {:ok, id}
    else
      claim_unused_id(next_id(id, min_id, max_id), min_id, max_id, remaining - 1, unit_type)
    end
  end

  defp next_id(max_id, min_id, max_id), do: min_id
  defp next_id(id, _min_id, _max_id), do: id + 1
end
