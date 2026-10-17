defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ReflectShield do
  @moduledoc """
  Reflect Shield (SC_REFLECTSHIELD).

  Toggled by CR_REFLECTSHIELD while a shield is equipped, for 300 seconds.
  Implements `after_damage_taken/4`: `val1` carries the skill level, and every
  short-range physical or misc hit that is neither reflected nor redirected
  reflects `(10 + 3 * val1)` percent of the delivered damage back to the
  attacker. A short trap hit on a player whose equipment returns melee damage
  (`trap_return?`) is returned by that equipment instead. A copy
  inherited through Devotion (`state.inherited`) reflects skills only, and a
  devotee standing out of its Crusader's Devotion range reflects nothing.

  The shield requirement is checked at cast time; the `:remove_on_unequip_shield`
  flag drops the stance if the shield is later removed without a replacement.
  It starts and ends its devotees' copies (`DevotionMirror`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_reflectshield,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    duration: 300_000,
    no_save: true,
    properties: [:buff],
    flags: [:remove_on_unequip_shield],
    icon: :reflectshield

  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Devotion
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @impl true
  def on_apply(target, instance, context) do
    DevotionMirror.started(target, instance, instance.state, context.duration)
    {:ok, instance}
  end

  @impl true
  def on_expire(target, instance, _context), do: DevotionMirror.ended(target, instance)

  @impl true
  @spec after_damage_taken({atom(), integer()}, StatusEntry.t(), map(), map()) ::
          :ok | {:reflect, non_neg_integer()}
  def after_damage_taken(target, %StatusEntry{val1: level} = entry, hit_info, _context) do
    if reflectable?(hit_info) and reflects?(target, entry, hit_info) do
      amount = div(hit_info.damage * (10 + 3 * level), 100)

      if amount > 0 do
        SpecialEffect.play(target, :reflectshield, :area)
        {:reflect, amount}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp reflects?({:player, id}, entry, hit_info) do
    not (inherited?(entry) and is_nil(Map.get(hit_info, :skill_id))) and
      not Devotion.beyond_range?(id)
  end

  defp reflects?(_target, _entry, _hit_info), do: true

  defp inherited?(%StatusEntry{state: %{inherited: true}}), do: true
  defp inherited?(_entry), do: false

  defp reflectable_type?(%{dmg_type: :physical}), do: true

  defp reflectable_type?(%{dmg_type: :misc} = hit_info),
    do: not Map.get(hit_info, :trap_return?, false)

  defp reflectable_type?(_hit_info), do: false

  defp reflectable?(hit_info) do
    not Map.has_key?(hit_info, :infinite_defense) and
      reflectable_type?(hit_info) and
      Map.get(hit_info, :is_short, false) == true and
      not Map.get(hit_info, :reflected, false) and
      not Map.get(hit_info, :redirected, false)
  end
end
