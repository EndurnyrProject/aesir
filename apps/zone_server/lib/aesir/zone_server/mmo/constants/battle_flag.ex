defmodule Aesir.ZoneServer.Mmo.BattleFlag do
  @moduledoc """
  e_battle_flag (BF_*) attack-classification bits.

  An attack is described along three independent axes: damage type
  (weapon/magic/misc), range (short/long), and origin (skill/normal). Item
  bonuses use the same bits to say which attacks they trigger on.
  """

  @ids %{
    none: 0x0000,
    weapon: 0x0001,
    magic: 0x0002,
    misc: 0x0004,
    short: 0x0010,
    long: 0x0040,
    skill: 0x0100,
    normal: 0x0200
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
