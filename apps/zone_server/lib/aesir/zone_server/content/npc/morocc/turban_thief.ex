defmodule Aesir.ZoneServer.Content.Npc.Morocc.TurbanThief do
  @moduledoc """
  The Sphinx Mask quest NPC, ported from rAthena's `npc/custom/quests/sphinx_mask.txt`.

  A single-NPC, one-time-reward quest: the Turban Thief sells the Masque of
  Tutankhamen (item `7114`) once per character through a 3-tier haggle menu
  (1,000,000 / 750,000 / 500,000z). Buying it sets the permanent char var
  `sphmask_q`; talking again after that hits the "go away" gate.

  ## Porting deviations from the rAthena source

  * **Dropped the `event_umbala < 2` cross-quest prerequisite** (the intended,
    spec-noted deviation): the original gates the whole interaction behind the
    Umbalian Chief quest line, which is out of scope here. Only the `sphmask_q`
    one-time gate is kept.
  * **`sphmask_q` is set only on a completed purchase.** rAthena also sets it on
    the "Ack! Forgez it!" walk-away (a quirk that would lock a player out after
    merely browsing). We set it solely when the deal closes, so declining keeps
    the quest available — closer to player intent and to how the var name reads.
  * Haggle flavor text is a concise port of the per-tier `L_Menu` lines.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [%{map: "morocc", x: 208, y: 90, dir: 6, sprite: 58, name: "Turban Thief"}]

  @reward_item_id 7114
  @prices [1_000_000, 750_000, 500_000]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :sphmask_q, 0) == 1 do
      ctx
      |> mes("[Turban Thief]")
      |> mes("You have no more business with me, go away!")
      |> close()
    else
      offer(ctx)
    end
  end

  defp offer(ctx) do
    ctx =
      ctx
      |> mes("[Turban Thief]")
      |> mes("E'llo mah frien, would I interesst tu with this rare mask? Tis manific!")

    case select(ctx, ["Pay 1,000,000z", "Pay 750,000z", "Pay 500,000z", "No deal"]) do
      {ctx, choice} when choice in 1..3 ->
        haggle(ctx, Enum.at(@prices, choice - 1))

      {ctx, _no_deal_or_cancel} ->
        ctx
        |> mes("[Turban Thief]")
        |> mes("Ack! Forgez it! I can do bettaz en elsez where!")
        |> close()
    end
  end

  defp haggle(ctx, price) do
    if zeny(ctx) < price do
      ctx
      |> mes("[Turban Thief]")
      |> mes("Are youz playin wit me? You don't have ze money!")
      |> close()
    else
      ctx
      |> pay_zeny(price)
      |> give_item(@reward_item_id, 1)
      |> set_char_var(:sphmask_q, 1)
      |> mes("[Turban Thief]")
      |> mes("O ho ho, it's a deal, then!")
      |> close()
    end
  end
end
