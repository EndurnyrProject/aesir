defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ChaseWalk2 do
  @moduledoc """
  Chase Walk's STR bonus (SC_CHASEWALK2).

  In renewal and pre-renewal, adds `val1` STR (`2 ** (level - 1)`, from 1 at
  Chase Walk level 1 to 16 at level 5) for 30 s. It is not saved at logout and
  ends on a map change or under Hermode.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_chasewalk2,
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:str],
    no_save: true,
    remove_on_map_change: true,
    icon: :chasewalk2

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: %{str: integer()}
  def modifiers(%StatusEntry{val1: str}, _context), do: %{str: str}
end
