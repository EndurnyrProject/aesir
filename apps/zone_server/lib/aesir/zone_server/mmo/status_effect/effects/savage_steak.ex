defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SavageSteak do
  @moduledoc """
  Savage Steak cooked-food buff (SC_SAVAGE_STEAK).

  Raises STR by `val1` for the duration (`db/re/status.yml`: `bStr,
  getstatus(SC_SAVAGE_STEAK,1)`). Magnitude and duration come from the consumed
  item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_savage_steak,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:str],
    icon: :savage_steak

  @impl true
  def modifiers(instance, _context), do: %{str: instance.val1}
end
