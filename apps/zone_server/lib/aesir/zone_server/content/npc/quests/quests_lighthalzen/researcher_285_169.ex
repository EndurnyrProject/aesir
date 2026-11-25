defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Researcher285169 do
  @moduledoc """
  Lestin helps the player infiltrate the secret archive.

  ## Behavior

  - Provides an archive pass and explains the search.
  - Recovers the pass after the player finds the evidence.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 285,
        y: 169,
        dir: 3,
        sprite: 865,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7349, 1}]) != 1 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) < 27 ->
        ctx
        |> mes("[Researcher]")
        |> mes("This is a restricted")
        |> mes("area. Please leave")
        |> mes("immediately.")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) == 27 ->
        ctx
        |> mes("[Lestin]")
        |> mes("This place should be")
        |> mes("safe enough for us to talk")
        |> mes("for now, so please listen")
        |> mes("carefully. Esuna must have")
        |> mes("told you that they beefed")
        |> mes("up security lately, right?")
        |> next()
        |> mes("[Lestin]")
        |> mes("Anyway, since my location")
        |> mes("is being monitored, I can't")
        |> mes("risk going inside there. You")
        |> mes("need to sneak in on your own")
        |> mes("when the guards change shifts. It's an old trick, but it works.")
        |> next()
        |> mes("[Lestin]")
        |> mes("My pass will get you inside,")
        |> mes("but you'll only be able to")
        |> mes("stick around for 3 minutes")
        |> mes("at a time. The Secret Archive is to the right of this laboratory.")
        |> set_char_var(:lhz_boss, 28)
        |> give_item(7349, 1)
        |> changequest(12_025, 12_026)
        |> next()
        |> mes("[Lestin]")
        |> mes("When you're finished,")
        |> mes("come back and give me")
        |> mes("the pass since it'll be real")
        |> mes("suspicious if I don't have it.")
        |> mes("Good luck to you. This job")
        |> mes("is risky, but not impossible.")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) < 35 ->
        ctx
        |> mes("[Lestin]")
        |> mes("Remember, you gotta")
        |> mes("sneak past that set of")
        |> mes("two guards while they're")
        |> mes("changing shifts. If you hide")
        |> mes("behind a corner and wait for")
        |> mes("a bit, you should get lucky.")
        |> next()
        |> mes("[Lestin]")
        |> mes("Once you sneak into the")
        |> mes("Secret Archive, look for")
        |> mes("the File Search Engine that")
        |> mes("should be right next to the")
        |> mes("door. You gotta use to find")
        |> mes("specific information, okay?")
        |> next()
        |> mes("[Lestin]")
        |> mes("My suggestion? You really")
        |> mes("ought to look for any files")
        |> mes("containing any information")
        |> mes("regarding ^3355FFRekenber's secret")
        |> mes("that Shinokas discovered^000000.")
        |> next()
        |> mes("[Lestin]")
        |> mes("Remember that this pass")
        |> mes("will get you into the Secret")
        |> mes("Archive for only 3 minutes")
        |> mes("at a time. Be really careful")
        |> mes("and don't get caught!")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) == 35 and
          (not Rathena.truthy?(count_item(ctx, 7349)) or
             not Rathena.truthy?(count_item(ctx, 7344))) ->
        ctx
        |> mes("[Lestin]")
        |> mes("My pass will get you inside,")
        |> mes("but you'll only be able to")
        |> mes("stick around for 3 minutes")
        |> mes("at a time. The Secret Archive is to the right of this laboratory.")
        |> next()
        |> mes("[Lestin]")
        |> mes("When you're finished,")
        |> mes("come back and give me")
        |> mes("the pass since it'll be real")
        |> mes("suspicious if I don't have it.")
        |> mes("Good luck to you. This job")
        |> mes("is risky, but not impossible.")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) == 35 ->
        ctx
        |> mes("[Lestin]")
        |> mes("You found what you were")
        |> mes("looking for? That must have")
        |> mes("been like looking for a needle")
        |> mes("in a haystick, but you managed")
        |> mes("to do it. Great work, guy~")
        |> next()
        |> mes("[Lestin]")
        |> mes("It's a good thing you")
        |> mes("found that when you did.")
        |> mes("Although it'd help to steal")
        |> mes("even more intel, sticking")
        |> mes("around even longer makes")
        |> mes("it easier for us to get caught.")
        |> next()
        |> mes("[Lestin]")
        |> mes("Alright, you better get")
        |> mes("out of here and find Esuna")
        |> mes("now. Watch your back and")
        |> mes("be careful. We're not all")
        |> mes("clear until this is all over.")
        |> next()
        |> mes("[Lestin]")
        |> mes("Esuna should be right")
        |> mes("outside of the city of")
        |> mes("Lighthalzen where you")
        |> mes("found her last time. She'll")
        |> mes("know that you're coming.")
        |> delitem(7349, 1)
        |> set_char_var(:lhz_boss, 36)
        |> changequest(12_026, 12_027)
        |> close()

      true ->
        ctx
        |> mes("[Lestin]")
        |> mes("Oh man...")
        |> mes("Everyone here is")
        |> mes("getting too paranoid")
        |> mes("for their own good!")
        |> mes("You better steer clear")
        |> mes("from this place for now.")
        |> close()
    end
  end
end
