defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Battleorder do
  @moduledoc """
  Battle Orders (SC_BATTLEORDER). Guild area buff granting flat +5
  STR/INT/DEX for the duration (reference adds a fixed 5 to each stat
  regardless of level).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_battleorder,
    properties: [:buff],
    no_dispel: false,
    no_save: true,
    calc_flags: [:str, :int, :dex]

  @modifiers %{str: 5, int: 5, dex: 5}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
