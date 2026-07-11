defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StrScroll do
  @moduledoc """
  STR scroll buff (SC_STR_SCROLL).

  Raises STR by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Str_Scroll`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_str_scroll,
    properties: [:buff],
    calc_flags: [:str],
    icon: :str_scroll

  @impl true
  def modifiers(instance, _context), do: %{str: instance.val1}
end
