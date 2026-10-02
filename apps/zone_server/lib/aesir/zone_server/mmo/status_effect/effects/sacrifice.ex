defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sacrifice do
  @moduledoc """
  Martyr's Reckoning (SC_SACRIFICE).

  For the holder's next five ordinary swings, each swing becomes a Martyr's
  Reckoning strike: 9% of the holder's maximum HP as the base, at
  `90 + 10 * level` percent, ignoring the target's DEF and FLEE, the weapon
  size penalty, and the holder's status ATK bonuses. Every swing costs the
  holder 9% of maximum HP, charged after the strike resolves, so the fifth
  swing can kill the holder. The status ends when the fifth swing is spent,
  never by timer. Identical in both game modes; pre-renewal only adds an
  after-cast delay on the skill itself.

  Accepted deviations from the reference mechanics: the strike cannot be
  perfect-dodged (the replacement path does not roll it), renewal's Auto Guard
  bypass is not modelled, and the status is not kept across relog.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sacrifice,
    no_dispel: false,
    no_save: true,
    permanent: true,
    properties: [:buff],
    target_types: [:player],
    icon: :sacrifice

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @skill_id 368
  @swings 5
  @hp_share_percent 9

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()}
  def on_apply(_target, instance, _context),
    do: {:ok, Helpers.put_state(instance, :remaining, @swings)}

  @impl true
  @spec attack_replacement(Definition.target(), StatusEntry.t(), Definition.context()) ::
          Definition.attack_replacement_result()
  def attack_replacement(
        {:player, id} = target,
        %StatusEntry{val1: level, state: %{remaining: remaining}},
        %{target: %{max_hp: max_hp}}
      ) do
    spend_swing(id, remaining)
    cost = div(max_hp * @hp_share_percent, 100)
    Helpers.deal_damage(target, cost)

    {:skill_attack,
     [
       skill_id: @skill_id,
       skill_level: level,
       base_damage: cost,
       skill_ratio: 90 + 10 * level,
       ignore_defense: true,
       ignore_flee: true,
       ignore_size: true,
       skip_crit: true,
       skip_status_atk: true
     ]}
  end

  def attack_replacement(_target, _instance, _context), do: :normal

  defp spend_swing(id, remaining) when remaining <= 1,
    do: Interpreter.remove_status(:player, id, :sc_sacrifice)

  defp spend_swing(id, _remaining) do
    StatusStorage.update_status(:player, id, :sc_sacrifice, fn entry ->
      Helpers.put_state(entry, :remaining, entry.state.remaining - 1)
    end)
  end
end
