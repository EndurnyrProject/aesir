defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DeadlyPoison do
  @moduledoc """
  Deadly Poison (SC_DPOISON).

  Strong damage over time that stops regeneration and reduces defense. Starting
  it (not restoring it) takes 10% of a player's Max HP, 15% of anyone else's,
  at once as passive loss, never below a quarter of Max HP and only while HP is
  above that quarter. Each second it then damages only while HP stays above
  `max(max_hp / 4, tick damage)`: players take `2 + max_hp / 50`, any other
  unit `2 + max_hp / 100`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_dpoison,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :damage_over_time],
    calc_flags: [:def, :regen],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon],
    prevented_by: [:sc_refresh, :sc_inspiration],
    tick_interval: 1_000,
    opt2: :dpoison

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  def modifiers(_instance, %{unit_type: unit_type, target_id: target_id}) do
    if slow_poison?(unit_type, target_id) do
      %{def_rate: -25}
    else
      %{hp_regen: -100, sp_regen: -100, def_rate: -25}
    end
  end

  @impl true
  def on_apply(target, instance, %{loaded: false, target: %{hp: hp, max_hp: max_hp}}) do
    quarter = div(max_hp, 4)

    if hp > quarter do
      loss = min(div(max_hp * if(player?(target), do: 10, else: 15), 100), hp - quarter)
      if loss > 0, do: apply_passive_hp_loss(target, loss)
    end

    {:ok, instance}
  end

  def on_apply(_target, instance, _context), do: {:ok, instance}

  @impl true
  def on_tick(target, instance, context) do
    stats = context.target

    damage =
      if player?(target) do
        2 + div(stats.max_hp, 50)
      else
        2 + div(stats.max_hp, 100)
      end

    if not slow_poison?(target) and stats.hp > max(div(stats.max_hp, 4), damage) do
      deal_damage(target, max(damage, 1))
    end

    {:ok, instance}
  end

  defp slow_poison?({unit_type, target_id}), do: slow_poison?(unit_type, target_id)

  defp slow_poison?(unit_type, target_id),
    do: StatusStorage.has_status?(unit_type, target_id, :sc_slowpoison)
end
