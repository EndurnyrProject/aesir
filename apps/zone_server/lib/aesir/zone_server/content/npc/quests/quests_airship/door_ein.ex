defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.DoorEin do
  @moduledoc """
  Advances the search for Defru at the Einbroch hotel.

  ## Behavior

  - At ticket quest stage five, records the empty room and the player’s next objective.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 227,
        y: 279,
        dir: 3,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#door_ein",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)

  @impl true
  def on_talk(ctx), do: ev_ontouch(ctx)

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :kain_ticket, 0) == 5 do
      ctx = set_char_var(ctx, :kain_ticket, 6)

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Excuse me...?")
        |> next()
        |> mes("^3355FFNo one's here!^000000")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("This must be the room...")
        |> mes("But where the hell is he?")
        |> mes("I can't just leave this stuff")
        |> mes("here if he won't come back.")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Oh well...")
        |> mes("I guess I can")
        |> mes("just give this")
        |> mes("back to Kain")
        |> mes("on the Airship.")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("While I'm in Einbroch,")
        |> mes("I may as well take a look")
        |> mes("around here and see if I can")
        |> mes("find anything interesting. Still, I can't help but think of Kain")
        |> mes("Himere's long lost daughter... ")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Maybe...")
        |> mes("Just maybe...")
        |> mes("I can find some")
        |> mes("sort of clue about")
        |> mes("where she is. She might")
        |> mes("even live here in Einbroch.")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I think I'll do that.")
      |> mes("Maybe even right this")
      |> mes("minute. Treat it like")
      |> mes("sort of quest or something.")
      |> mes("Yeah, that could work.")
      |> close()
    else
      ctx
    end
  end
end
