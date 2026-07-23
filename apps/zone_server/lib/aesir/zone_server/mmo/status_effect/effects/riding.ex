defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Riding do
  @moduledoc """
  Riding (SC_RIDING).

  Permanent status attached while a Peco-Peco is mounted. It carries both the
  mount's move-speed bonus and the ASPD penalty that Cavalier Mastery buys
  back, plus the sprite's mounted appearance.

  ## Instance convention

    - `val1` — the rider's learned Cavalier Mastery level (0..5), captured at
      mount time. Drives the ASPD penalty, which shrinks to 0 at max level.

  ## Modifiers

  Movement uses the additive percent convention where negative means faster
  (`status_manager.ex:walk_speed_for/1`): mounted movement is a flat `-25`
  (25% faster), independent of Cavalier Mastery.

  ASPD uses the flat fixed-bonus bucket read by `Stats.calculate_aspd/1`
  (the `:aspd` status modifier folded into `flat_bonus * agi / 200`, the
  same bucket quicken-style buffs use), not the percent `aspd_rate` path.
  Riding is a penalty, so it emits a negative flat value that shrinks
  toward 0 as Cavalier Mastery is trained:

      aspd = -(50 - 10 * cavalier_mastery_level)

  At level 0 the full 50-point penalty applies (scaled by AGI/200 like every
  fixed ASPD bonus); at level 5 it is entirely bought back.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_riding,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:speed, :aspd],
    permanent: true,
    no_save: true,
    option: :riding

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def modifiers(%StatusEntry{val1: cavalier_mastery_level}, _context) do
    %{movement_speed: -25, aspd: -(50 - 10 * cavalier_mastery_level)}
  end
end
