defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Bleeding do
  @moduledoc """
  Bleeding (SC_BLEEDING).

  Stops HP/SP regeneration and every 10 seconds takes a uniform 200 to 799 HP
  as passive loss. A player can bleed to death; any other unit stops at 1 HP.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_bleeding,
    immunity: [:boss],
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:debuff, :damage_over_time],
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    tick_interval: 10_000,
    no_save: true,
    icon: :blooding,
    opt2: :bleeding

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(_instance, _context), do: %{no_regen: true}

  @impl true
  def on_tick(target, instance, _context) do
    damage = :rand.uniform(600) + 199

    if player?(target),
      do: deal_damage(target, damage),
      else: apply_passive_hp_loss(target, damage)

    {:ok, instance}
  end
end
