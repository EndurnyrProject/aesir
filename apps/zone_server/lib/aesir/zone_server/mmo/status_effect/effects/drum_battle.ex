defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DrumBattle do
  @moduledoc """
  Drum of the Battlefield (SC_DRUMBATTLE), keyed by the skill level in `val1`.

  Renewal: live equipment ATK `15 + 5 * level`, added after card modifiers
  and before EDP, plus DEF `15 * level`. ATK is not part of the cached stat
  calculation. New starts capture those amounts in val2/val3; loaded starts
  retain their saved values. The status ends the other ensembles' statuses.
  Pre-renewal: the ensemble field grants weapon ATK
  `(level + 1) * 25` and DEF `(level + 1) * 2`, ends no other status and lasts
  60 seconds.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_drumbattle,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    flags: [:no_clearance, :no_banishing_buster],
    calc_flags: [renewal: [:def], pre_renewal: [:watk, :def]],
    end_on_start: [
      renewal: [
        :sc_richmankim,
        :sc_eternalchaos,
        :sc_drumbattle,
        :sc_nibelungen,
        :sc_rokisweil,
        :sc_intoabyss,
        :sc_siegfried
      ],
      pre_renewal: []
    ],
    duration: [renewal: 180_000, pre_renewal: 60_000],
    remove_on_death: true,
    remove_on_map_change: false,
    icon: :drumbattlefield

  alias Aesir.Commons.GameMode

  @impl true
  def on_apply(_target, instance, %{loaded: false}) do
    case GameMode.mode() do
      :renewal -> {:ok, %{instance | val2: 15 + 5 * instance.val1, val3: 15 * instance.val1}}
      :pre_renewal -> {:ok, instance}
    end
  end

  def on_apply(_target, instance, _context), do: {:ok, instance}

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{post_card_equip_atk: instance.val2, def: instance.val3}
      :pre_renewal -> %{watk: (instance.val1 + 1) * 25, def: (instance.val1 + 1) * 2}
    end
  end
end
