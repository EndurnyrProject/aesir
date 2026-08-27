defmodule Aesir.ZoneServer.Mmo.AutoTriggerFlag do
  @moduledoc """
  auto_trigger_flag (ATF_*) on-hit status trigger bits.

  The on-hit status families qualify their proc with these: the same damage
  type and range axes `Aesir.ZoneServer.Mmo.BattleFlag` carries, plus a victim
  axis choosing between the attack's other party and the bonus's own wearer.

  `:skill` is the alias for the two damage types that only ever come from a
  skill.
  """

  @ids %{
    self: 0x01,
    target: 0x02,
    short: 0x04,
    long: 0x08,
    weapon: 0x10,
    magic: 0x20,
    misc: 0x40,
    skill: 0x60
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
