defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Id do
  @moduledoc """
  Allocates stable skill-unit IDs from `0x5800_0000..0x5FFF_FFFF`.

  This uint32 range follows static NPC IDs (`0x5000_0000..0x57FF_FFFF`) and is
  disjoint from player, mob, warp, shop, and ground-item IDs.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Unit.UnitRegistry

  @first 0x5800_0000
  @last 0x5FFF_FFFF

  @spec first() :: non_neg_integer()
  def first, do: @first
  @spec last() :: non_neg_integer()
  def last, do: @last
  @spec skill_unit?(integer()) :: boolean()
  def skill_unit?(id), do: is_integer(id) and id in @first..@last

  @doc "Allocates an unused skill-unit ID. The manager serializes all callers."
  @spec allocate(keyword()) :: {:ok, non_neg_integer()} | {:error, :id_exhausted}
  def allocate(opts \\ []) do
    start = Keyword.get(opts, :start, @first)
    allocate_from(normalize(start), @last - @first + 1)
  end

  defp allocate_from(_id, 0), do: {:error, :id_exhausted}

  defp allocate_from(id, remaining) do
    if occupied?(id) do
      allocate_from(next(id), remaining - 1)
    else
      {:ok, id}
    end
  end

  defp occupied?(id) do
    :ets.member(table_for(:skill_unit_cells), id) or
      UnitRegistry.unit_id_exists?(id)
  end

  defp normalize(id) when id < @first or id > @last, do: @first
  defp normalize(id), do: id
  defp next(@last), do: @first
  defp next(id), do: id + 1
end
