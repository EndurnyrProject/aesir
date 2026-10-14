defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.VitalizePotion do
  @moduledoc """
  Vitalize Potion buff (SC_VITALIZE_POTION).

  Grants the item-script ATK rate (`bonus_atk_rate`: `val1` percent of weapon
  and equipment ATK, renewal only) and MATK rate (`matk_rate`).
  """
  # NOTE: Deferred riders (no modifier vocabulary yet): +10 heal power and +10
  #   received-item-heal. status.yml defines them alongside the damage rates;
  #   add them once heal-power / item-heal modifier keys exist.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_vitalize_potion,
    no_dispel: [renewal: false, pre_renewal: true],
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:atk, :matk_rate],
    icon: :vitalize_potion

  @impl true
  def modifiers(instance, _context) do
    val1 = instance.val1
    %{bonus_atk_rate: val1, matk_rate: val1}
  end
end
