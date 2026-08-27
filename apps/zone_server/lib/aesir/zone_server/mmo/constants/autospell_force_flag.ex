defmodule Aesir.ZoneServer.Mmo.AutospellForceFlag do
  @moduledoc """
  Autospell force flags: the extra argument of the equip autocast bonuses.

  Two independent bits qualify how a proc casts:

    * `:target` - who receives the cast. On an attack or when-hit proc the bit
      aims the cast at the attack's other party, and its absence casts on the
      wearer. The on-skill trigger reads the same bit the other way round: it
      is the bit that keeps the cast on the wearer.
    * `:random_level` - the proc rolls a level in `1..level` instead of always
      casting at the armed level.

  `:self` is the absence of the target bit, and `:all` is both bits set.
  """

  @ids %{
    self: 0x0,
    target: 0x1,
    random_level: 0x2,
    all: 0x3
  }

  @doc """
  Resolves a constant atom to its numeric id, or `nil` when unknown.
  """
  @spec id(atom()) :: integer() | nil
  def id(atom) when is_atom(atom), do: Map.get(@ids, atom)

  @doc "The whole constant table, keyed by atom."
  @spec ids() :: %{atom() => integer()}
  def ids, do: @ids
end
