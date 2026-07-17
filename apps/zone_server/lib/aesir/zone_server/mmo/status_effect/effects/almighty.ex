defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Almighty do
  @moduledoc """
  Almighty buff (SC_ALMIGHTY).

  Raises ATK and MATK by `val1`. Despite the name it is **not** an all-stats
  buff: `db/re/status.yml` defines only `bBaseAtk`/`bMatk` bonuses. Magnitude
  and duration come from the consumed item's `sc_start`. Starting it ends the
  overlapping Ultimate Cook buff (`EndOnStart`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_almighty,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:atk, :matk],
    icon: :almighty,
    end_on_start: [:sc_ultimatecook]

  @impl true
  def modifiers(instance, _context), do: %{atk: instance.val1, matk: instance.val1}
end
