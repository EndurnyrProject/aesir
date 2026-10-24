defmodule Aesir.ZoneServer.Mmo.MobManagement.PolymorphPool do
  @moduledoc """
  Mode-scoped monster choices for equipment polymorph: the Dead Branch group of
  `Aesir.ZoneServer.Mmo.MobManagement.SummonGroups`.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.SummonGroups

  @typedoc "A default monster and its candidate IDs with per-million acceptance rates."
  @type pool :: SummonGroups.pool()
  @typedoc "An inclusive uniform draw from 1 through the supplied upper bound."
  @type rng :: SummonGroups.rng()

  @doc "Chooses a replacement from the active mode's pool."
  @spec pick(rng()) :: non_neg_integer()
  def pick(rng \\ &:rand.uniform/1), do: SummonGroups.pick(0, rng)

  @doc "Chooses from a supplied pool with the same bounded rejection recipe."
  @spec choose(pool(), rng()) :: non_neg_integer()
  defdelegate choose(pool, rng), to: SummonGroups

  @doc "Reloads the pool after its YAML sources change."
  @spec reload() :: :ok
  defdelegate reload(), to: SummonGroups
end
