defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.VitalizePotion do
  @moduledoc """
  Vitalize Potion buff (SC_VITALIZE_POTION).

  Adds `val1` percent to both physical and magical damage (`db/re/status.yml`:
  `bAtkRate`/`bMatkRate, getstatus(SC_VITALIZE_POTION,1)`). val1-driven; the
  `atk_rate`/`matk_rate` deltas are consumed in the combat calculators.
  """
  # NOTE: Deferred riders (no modifier vocabulary yet): +10 heal power and +10
  #   received-item-heal. status.yml defines them alongside the damage rates;
  #   add them once heal-power / item-heal modifier keys exist.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_vitalize_potion,
    properties: [:buff],
    calc_flags: [:atk_rate, :matk_rate],
    icon: :vitalize_potion

  @impl true
  def modifiers(instance, _context) do
    val1 = instance.val1
    %{atk_rate: val1, matk_rate: val1}
  end
end
