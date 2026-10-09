defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WeaponPerfection do
  @moduledoc """
  Removes physical weapon size penalties while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_weaponperfection,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:atk],
    icon: :weaponperfect

  @impl true
  def modifiers(_instance, _context), do: %{ignore_size_penalty: true}
end
