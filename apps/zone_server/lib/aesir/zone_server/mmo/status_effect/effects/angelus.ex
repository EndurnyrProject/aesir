defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Angelus do
  @moduledoc """
  Angelus (SC_ANGELUS).

  A party defence buff whose magnitude (`val2`) is five percent per skill level.

  Renewal: the recipient gains flat soft defence worth half their fully
  calculated VIT (allocated points plus job, equipment and status contributions)
  scaled by that percentage, so the buff is worth the same to a party member
  whatever their existing defence, and it also grants flat maximum HP of fifty
  points per skill level.

  Pre-renewal: the recipient's existing soft defence is raised by that
  percentage instead, so the buff is worth more to an already tough character
  and nothing at all to one with no soft defence, and there is no maximum-HP
  bonus.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_angelus,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:def2, :maxhp],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :angelus,
    opt2: :angelus

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, context) do
    case GameMode.mode() do
      :renewal ->
        vit = context.target.total_stats.vit

        %{vit_bonus: div(div(vit, 2) * instance.val2, 100), max_hp: 50 * instance.val1}

      :pre_renewal ->
        %{def2_rate: instance.val2}
    end
  end
end
