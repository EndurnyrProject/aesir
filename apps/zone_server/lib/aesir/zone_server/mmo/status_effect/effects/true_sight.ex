defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TrueSight do
  @moduledoc """
  True Sight grants +5 to all six stats, level critical, three times level HIT,
  and twice level percent ATK in both renewal and pre-renewal. Quagmire prevents it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_truesight,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:str, :agi, :vit, :int, :dex, :luk, :critical, :hit],
    prevented_by: [:sc_quagmire],
    no_save: true,
    icon: :truesight

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: map()
  def modifiers(%{val1: level}, _context) do
    %{
      str: 5,
      agi: 5,
      vit: 5,
      int: 5,
      dex: 5,
      luk: 5,
      critical: level,
      hit: 3 * level,
      atk_rate: 2 * level
    }
  end
end
