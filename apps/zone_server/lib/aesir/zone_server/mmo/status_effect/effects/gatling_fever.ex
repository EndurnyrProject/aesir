defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GatlingFever do
  @moduledoc """
  Gatling Fever increases equipment ATK and flat ASPD in renewal, or base ATK
  and the strongest ASPD rate in pre-renewal. Both modes reduce FLEE and speed.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gatlingfever,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [renewal: [:flee, :speed, :aspd], pre_renewal: [:flee, :speed, :aspd, :batk]],
    flags: [:no_banishing_buster],
    require_weapon: [:gatling],
    icon: :gs_gatlingfever

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    common = %{flee: -instance.val4, movement_speed: 100}

    case GameMode.mode() do
      :renewal ->
        Map.merge(common, %{post_card_equip_atk: instance.val3, aspd: instance.val1})

      :pre_renewal ->
        Map.merge(common, %{batk: instance.val3, aspd_rate_max: div(instance.val2, 10)})
    end
  end
end
