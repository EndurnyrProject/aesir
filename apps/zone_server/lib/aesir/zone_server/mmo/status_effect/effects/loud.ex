defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Loud do
  @moduledoc """
  Crazy Uproar (SC_LOUD). Renewal grants +4 STR and +30 base ATK; classic grants
  +4 STR only.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_loud,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:str, :atk]

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(_instance, _context) do
    case GameMode.mode() do
      :renewal -> %{str: 4, batk: 30}
      :pre_renewal -> %{str: 4}
    end
  end
end
