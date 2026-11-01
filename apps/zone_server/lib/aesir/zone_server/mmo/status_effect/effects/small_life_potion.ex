defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SmallLifePotion do
  @moduledoc """
  Small Life Potion grants periodic percentage HP recovery in both modes.

  The recovery percentage is the negation of `val1`; `val2` is the interval
  in seconds. The consumable restores 5% every 5 seconds. Berserk removes
  the recovery contribution. Recovery shares the player's periodic regeneration
  cadence, restarts on a full stat recalculation and is not a status timer.

  Pre-renewal refuses another application while this status is held and keeps
  it through death. Renewal allows refreshes and removes it on death. Logout
  preserves the remaining status lifetime and parameters, not interval progress.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_s_lifepotion,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: false,
    remove_on_death: [renewal: true, pre_renewal: false],
    prevented_by: [renewal: [], pre_renewal: [:sc_s_lifepotion]],
    properties: [:buff],
    icon: :s_lifepotion

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(instance, %{unit_type: type, target_id: id}) do
    if StatusStorage.has_status?(type, id, :sc_berserk),
      do: %{},
      else: %{{:percent_hp_regen_bonus, {instance.type, instance.val2 * 1_000}} => -instance.val1}
  end
end
