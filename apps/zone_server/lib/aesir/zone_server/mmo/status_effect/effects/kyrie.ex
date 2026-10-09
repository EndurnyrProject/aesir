defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Kyrie do
  @moduledoc """
  Kyrie Eleison (SC_KYRIE).

  A holy barrier with a damage budget (val2) and a hit count (val3), the first
  blocker after the common damage stage. Every attack still carrying damage
  spends its damage from the budget and one hit from the count. Only weapon
  hits and Throw Stone are absorbed: they keep only the amount the budget could
  not cover. The barrier ends when either runs out, and Holy Light or Gloria
  Domini ends it after spending it.

  Pre-renewal Kyrie and Assumptio end each other on application; renewal lets
  them coexist.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_kyrie,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    prevented_by: [:sc_refresh, :sc_inspiration],
    end_on_start: [renewal: [], pre_renewal: [:sc_assumptio]],
    icon: :kyrie

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @throw_stone 152
  @holy_light 156
  @gloria_domini 367

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, shield_hp: instance.val2, hits_remaining: instance.val3)}
  end

  @impl true
  def absorb_damage(_target, instance, %{damage: damage} = hit, _context) do
    shield_hp = instance.state.shield_hp - damage
    hits = instance.state.hits_remaining - 1
    skill_id = Map.get(hit, :skill_id)
    left = if absorbed?(hit, skill_id), do: max(-shield_hp, 0), else: damage

    if hits <= 0 or shield_hp <= 0 or skill_id in [@holy_light, @gloria_domini] do
      {:remove, left}
    else
      {:ok, left, put_state(instance, shield_hp: shield_hp, hits_remaining: hits)}
    end
  end

  defp absorbed?(%{dmg_type: :physical}, _skill_id), do: true
  defp absorbed?(_hit, skill_id), do: skill_id == @throw_stone
end
