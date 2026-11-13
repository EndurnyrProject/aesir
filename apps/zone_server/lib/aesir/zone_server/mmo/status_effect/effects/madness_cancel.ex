defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MadnessCancel do
  @moduledoc """
  Madness Canceller (SC_MADNESSCANCEL), `val1` the skill level. Lasts 15 s,
  roots the holder and ends Adjustment when it starts.

  Starting it while it is held ends it instead of restarting it; the cast still
  spends its requirements. Renewal adds 100 equipment ATK and floors the flat
  attack speed bonus at 20, in Berserk's slot after Quagmire and the Assassin
  Cross song. Pre-renewal adds 100 base ATK and a 20% attack speed rate (a 200
  `aspd_rate` cut) that Berserk overrides.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_madnesscancel,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff, :prevents_movement],
    calc_flags: [renewal: [:aspd], pre_renewal: [:batk, :aspd]],
    flags: [:no_banishing_buster],
    prevented_by: [:sc_p_alter, :sc_heat_barrel],
    end_on_start: [:sc_adjustment],
    duration: 15_000,
    icon: :gs_madnesscancel

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.Commons.GameMode

  @impl true
  def before_overlap(target, _instance, %{loaded: false}) do
    if has_status?(target, :sc_madnesscancel),
      do: {:end_only, [:sc_madnesscancel]},
      else: :continue
  end

  def before_overlap(_target, _instance, _context), do: :continue

  @impl true
  def modifiers(_instance, _context) do
    case GameMode.mode() do
      :renewal -> %{post_card_equip_atk: 100, aspd_rate_strongest: 20}
      :pre_renewal -> %{batk: 100, aspd_rate_strongest: 20}
    end
  end
end
