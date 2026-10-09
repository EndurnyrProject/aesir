defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Defender do
  @moduledoc """
  Defending Aura (SC_DEFENDER). A 180-second toggle that trades speed for
  reduced long-range weapon damage: `val1` is the skill level (1..5).

  Started on its own it fixes `state.reduction` (5 + 15 per level percent) and
  `state.aspd_penalty` (250 - 50 per level); a Devotion copy carries its
  Crusader's figures, or none when inherited at link time. In the common damage
  stage, after any Assumptio reduction and before Blinding Mist, a long-range
  weapon hit loses `damage * reduction / 100` (the removed amount is
  truncated). The walk delay is floored at 200 ms per cell in both modes.
  Renewal loses a tenth of the penalty as flat attack speed; pre-renewal loses
  the same figure as a percentage rate. It starts and ends its devotees' copies
  (`DevotionMirror`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_defender,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate, :speed],
    flags: [:remove_on_unequip_shield],
    icon: :defender,
    duration: 180_000,
    no_save: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def on_apply(target, instance, context) do
    state =
      if DevotionMirror.copy?(instance),
        do: instance.state,
        else:
          Map.merge(instance.state, %{
            reduction: 5 + 15 * instance.val1,
            aspd_penalty: 250 - 50 * instance.val1
          })

    DevotionMirror.started(target, instance, state, context.duration)
    {:ok, %{instance | state: state}}
  end

  @impl true
  def on_expire(target, instance, _context), do: DevotionMirror.ended(target, instance)

  @impl true
  def modifiers(%StatusEntry{state: state}, _context) do
    penalty = div(Map.get(state, :aspd_penalty, 0), 10)

    case GameMode.mode() do
      :renewal -> %{walk_speed_floor: 200, aspd: -penalty}
      :pre_renewal -> %{walk_speed_floor: 200, aspd_rate: -penalty}
    end
  end

  @impl true
  def absorb_damage(_target, %StatusEntry{state: state} = instance, hit, _context) do
    case hit do
      %{damage: damage, dmg_type: :physical, is_short: false} ->
        {:ok, damage - div(damage * Map.get(state, :reduction, 0), 100), instance}

      %{damage: damage} ->
        {:ok, damage, instance}
    end
  end
end
