defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Angelus do
  @moduledoc """
  Angelus (SC_ANGELUS).

  Increases VIT-based defense by a percentage (val2) and maximum HP by 5%.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_angelus,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:def2, :maxhp],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :angelus,
    opt2: :angelus

  @impl true
  def modifiers(instance, _context) do
    %{def2_rate: instance.val2, max_hp_rate: 5}
  end
end
