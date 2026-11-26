defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.YoungMan135299 do
  @moduledoc """
  Nosdan sings clues for the investigation.

  ## Behavior

  - Changes his song and response as the investigation progresses.

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
        map: "comodo",
        x: 135,
        y: 299,
        dir: 0,
        sprite: 809,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#sch2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :que_sch, 0)

    cond do
      progress < 22 ->
        ctx
        |> mes("[Nosdan]")
        |> mes("Have you come to hear")
        |> mes("my song? Ah, it's good")
        |> mes("that you've come to enjoy")
        |> mes("my melodious vo--wait,")
        |> mes("wait, where are you going?")
        |> close()

      progress == 22 ->
        ctx
        |> mes("[Nosdan]")
        |> mes("Ah, are you the one")
        |> mes("that Vitre mentioned")
        |> mes("in his message? Okay,")
        |> mes("please give me a moment.")
        |> next()
        |> mes("[Nosdan]")
        |> mes("^333333*Ahem ahem*^000000")
        |> mes("I'm ready. Now")
        |> mes("please listen..")
        |> next()
        |> mes("[Nosdan]")
        |> mes("Who dares stop the fearless")
        |> mes("warrior? Baphomet? Drake?")
        |> mes("No, they're too weak! His")
        |> mes("steps now head to the group")
        |> mes("of evil men trying to revive")
        |> mes("Satan Morocc. I mean, come on!")
        |> next()
        |> mes("[Nosdan]")
        |> mes("Sad news from an old comrade,")
        |> mes("the evil group discovered...")
        |> mes("Time to stop Satan Morocc's")
        |> mes("revival~ La la la la la la la")
        |> mes("la la la la la la la la la la")
        |> mes("la la la la la la la la la la")
        |> next()
        |> mes("[Nosdan]")
        |> mes("What'd you think?")
        |> mes("Um, don't ask me about")
        |> mes("the lyrics. Just a weird")
        |> mes("artistic quirk I guess.")
        |> mes("Oh, please sing that song")
        |> mes("to Vitre for me, okay?")
        |> set_char_var(:que_sch, 23)
        |> close()

      progress < 30 ->
        ctx
        |> mes("[Nosdan]")
        |> mes("Oh, you need to")
        |> mes("hear my song again?")
        |> mes("No problem! I guess")
        |> mes("you really like it~")
        |> next()
        |> mes("[Nosdan]")
        |> mes("Who dares stop the fearless")
        |> mes("warrior? Baphomet? Drake?")
        |> mes("No, they're too weak! His")
        |> mes("steps now head to the group")
        |> mes("of evil men trying to revive")
        |> mes("Satan Morocc. I mean, come on!")
        |> next()
        |> mes("[Nosdan]")
        |> mes("Sad news from an old comrade,")
        |> mes("the evil group discovered...")
        |> mes("Time to stop Satan Morocc's")
        |> mes("revival~ La la la la la la la")
        |> mes("la la la la la la la la la la")
        |> mes("la la la la la la la la la la")
        |> next()
        |> mes("[Nosdan]")
        |> mes("What'd you think?")
        |> mes("Um, don't ask me about")
        |> mes("the lyrics. Just a weird")
        |> mes("artistic quirk I guess.")
        |> mes("Oh, please sing that song")
        |> mes("to Vitre for me, okay?")
        |> close()

      true ->
        ctx
        |> mes("[Nosdan]")
        |> mes("Oh, no! I didn't!")
        |> mes("do anything wrong.")
        |> mes("I swear!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
