defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.BardTrigger do
  @moduledoc """
  Starts the overheard conversation between the two delegates.

  ## Behavior

  - Reveals the conversation during the investigation and restores the figures afterward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 176,
        y: 285,
        dir: 0,
        sprite: -1,
        name: "Bard Trigger",
        scope: :shared,
        unique_name: "Bard Trigger#sch",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :que_sch, 0) == 15 do
      ctx
      |> disablenpc("Corporate Figure#sch")
      |> disablenpc("Arunafeltz Figure#sch")
      |> enablenpc("Corporate Figure")
      |> enablenpc("Arunafeltz Figure")
      |> mes("[????]")
      |> mes("I guess the party")
      |> mes("will soon be over.")
      |> mes("Did you enjoy yourself?")
      |> next()
      |> mes("[??????]")
      |> mes("Yes, thank you, I had")
      |> mes("a great time. I'm sorry")
      |> mes("I gave you such short")
      |> mes("notice of my arrival, but")
      |> mes("you held this party anyway.")
      |> next()
      |> mes("[????]")
      |> mes("Don't mention it.")
      |> mes("You're a valued guest.")
      |> mes("It would shame me if I'd")
      |> mes("failed to entertain you.")
      |> next()
      |> mes("[??????]")
      |> mes("Ho ho, you certainly know")
      |> mes("how to be a good host~")
      |> next()
      |> mes("[????]")
      |> mes("Your words honor me.")
      |> next()
      |> mes("^3355FFThe man took a quick")
      |> mes("look around the room.^000000")
      |> next()
      |> mes("[????]")
      |> mes("No one's around.")
      |> mes("I have something to")
      |> mes("discuss with you before")
      |> mes("we get down to business.")
      |> next()
      |> mes("[??????]")
      |> mes("What kind of...?")
      |> next()
      |> mes("[????]")
      |> mes("I'll explain in detail")
      |> mes("someplace safer. The gist")
      |> mes("is that some rogues over in")
      |> mes("Arunafeltz are plotting to harm")
      |> mes("relations between Arunafeltz")
      |> mes("and the Rekenber Corporation.")
      |> next()
      |> mes("[??????]")
      |> mes("Oh... I see. Yes,")
      |> mes("we can't talk about")
      |> mes("that here. To tell the")
      |> mes("truth, I've suspected that")
      |> mes("something like that was")
      |> mes("going on... Yes, makes sense.")
      |> next()
      |> mes("[????]")
      |> mes("We should relocate")
      |> mes("so that we can talk")
      |> mes("a bit more freely.")
      |> mes("Please follow me,")
      |> mes("I already have")
      |> mes("a place prepared.")
      |> set_char_var(:que_sch, 16)
      |> close2()
      |> disablenpc("Corporate Figure")
      |> disablenpc("Arunafeltz Figure")
      |> enablenpc("Corporate Figure#sch")
      |> enablenpc("Arunafeltz Figure#sch")
    else
      ctx
    end
  end
end
