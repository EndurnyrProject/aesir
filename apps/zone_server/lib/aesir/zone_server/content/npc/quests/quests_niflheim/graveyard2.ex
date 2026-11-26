defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Graveyard2 do
  @moduledoc """
  A second half-buried Piano Keyboard near a Niflheim grave, found by touching the spot.

  ## Behavior

  - Players at this grave's step of either key route may pick up a Piano Keyboard, which
    advances their route by two steps.
  - Declining leaves the route unchanged.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "niflheim",
        x: 169,
        y: 71,
        dir: 1,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Graveyard2",
        trigger: {1, 1}
      }
    ]

  @piano_keyboard 7184

  @impl true
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :nif_esc, 0) in [6, 9], do: offer_key(ctx), else: ctx
  end

  @impl true
  def on_talk(ctx), do: ctx

  defp offer_key(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou found something")
      |> mes("half-buried near a grave.")
      |> mes("It looks very well-shaped.^000000")
      |> next()
      |> mes("^3355FFWould you like to pick it up?^000000")
      |> select(["Yes", "No"])

    ctx = if choice == 1, do: pick_up(ctx), else: ctx
    close(ctx)
  end

  defp pick_up(ctx) do
    ctx
    |> set_char_var(:nif_esc, get_char_var(ctx, :nif_esc, 0) + 2)
    |> give_item(@piano_keyboard, 1)
  end
end
