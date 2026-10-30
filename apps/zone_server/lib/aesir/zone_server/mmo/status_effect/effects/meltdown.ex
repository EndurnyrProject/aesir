defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Meltdown do
  @moduledoc """
  Shattering Strike (SC_MELTDOWN). Holds the skill level in val1, weapon break
  rate in val2 (100 times level) and armor break rate in val3 (70 times level).

  Both modes survive death and Dispel and discard the buff on logout. The
  shared weapon-hit stage reads these per-10,000 rates without adding a stat
  modifier or limiting the effect to normal swings.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_meltdown,
    no_dispel: true,
    no_clear_buff: false,
    no_save: true,
    remove_on_death: false,
    properties: [:buff],
    icon: :meltdown

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), map()) :: {:ok, StatusEntry.t()}
  def on_apply(_target, instance, _context),
    do: {:ok, %{instance | val2: 100 * instance.val1, val3: 70 * instance.val1}}
end
