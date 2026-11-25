defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Rus27 do
  @moduledoc """
  An unseen voice challenges adventurers entering Marozka’s cave.

  ## Behavior

  - Starts the cave trial for eligible adventurers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_que",
        x: 49,
        y: 22,
        dir: 3,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#rus27",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :rhea_rus_main, 0) == 8 and
         not Rathena.truthy?(get_char_var(ctx, :rhea_rus_quiz, 0)) do
      ctx =
        ctx
        |> mes("[Voice unidentified]")
        |> mes("Who dares to come into my cave!")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes(
          "Are you Marozka? Maria sent me! I need your 'Golden Thread' to make a 'Golden Key' to release her from the wall!"
        )
        |> next()
        |> mes("[Voice unidentified]")
        |> mes("...To make a 'Golden Key'?")
        |> mes("Do you think that you are right for this job?")
        |> next()
        |> mes("[Voice unidentified]")
        |> mes(
          "You must be fighting against 'Koshei' if you are asking about the 'Golden Key' and Maria! Do you think that you are strong enough to fight against him?"
        )
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Of course I'm strong enough!")
      |> next()
      |> mes("[Voice unidentified]")
      |> mes("You are very confident.")
      |> mes("But, I need to test you to see if you truly are capable.")
      |> next()
      |> mes("[Voice unidentified]")
      |> mes("In this cave, there is a 'Stone Furnace' and an 'Apple Tree'.")
      |> mes(
        "You can escape from the cave with ^0000ff100 Well Baked Cookies^000000 from the Stone Furnace and ^0000ff100 Apples^000000 from the Apple Tree."
      )
      |> next()
      |> mes("[Voice unidentified]")
      |> mes(
        "It won't be easy. Monsters are wandering around the Stone Furnace and the Apple Tree."
      )
      |> next()
      |> mes("[Voice unidentified]")
      |> mes("Show me what you can do.")
      |> set_char_var(:rhea_rus_quiz, 1)
      |> close()
    else
      emotion(ctx, :question, playerattached(ctx))
    end
  end
end
