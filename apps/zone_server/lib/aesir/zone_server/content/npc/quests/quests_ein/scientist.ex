defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Scientist do
  @moduledoc """
  The scientist reveals information about the laboratory head.

  ## Behavior

  - Advances the murder quest when asked about his work.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 254,
        y: 35,
        dir: 1,
        sprite: 749,
        name: "Scientist",
        scope: :shared,
        unique_name: "Scientist#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Scientist]")
      |> mes("^333333*Grumble grumble*^000000")
      |> next()
      |> mes("[Scientist]")
      |> mes("Huh...?")
      |> mes("How did you")
      |> mes("get in here?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Oh! Ah....")
      |> mes("I'm the new...")
      |> mes("Guard. Nice")
      |> mes("to meet you.")
      |> next()
      |> mes("[Scientist]")
      |> mes("Oh. Yeah.")
      |> mes("Nice-meet-you.")
      |> mes("..............")
      |> mes("^333333*Grumble grumble*^000000")

    case get_char_var(ctx, :Shinokas_Quest, 0) do
      7 ->
        {ctx, choice} = ctx |> next() |> select(["What's wrong?", "Catch you later."])

        case choice do
          1 ->
            ctx
            |> mes("[Scientist]")
            |> mes("What's wrong...?!")
            |> mes("Oh, don't get me started!")
            |> mes("I'm stuck here doing all the")
            |> mes("work while the Lab Department Head goes out every freakin' day!")
            |> next()
            |> mes("[Scientist]")
            |> mes("While I'm slaving")
            |> mes("away here, he's in")
            |> mes("that Airship, busy")
            |> mes("flirting with that")
            |> mes("woman. God...!")
            |> mes("I'm like, so teed off!")
            |> set_char_var(:Shinokas_Quest, 8)
            |> close()

          2 ->
            ctx
            |> mes("[Scientist]")
            |> mes("Right.")
            |> mes("Yeah.")
            |> mes("Later, man.")
            |> close()

          _ ->
            ctx
        end

      8 ->
        ctx
        |> next()
        |> mes("[Scientist]")
        |> mes("Man alive!")
        |> mes("Would it kill the")
        |> mes("Department Head")
        |> mes("to come in here and do")
        |> mes("some work for a change?!")
        |> next()
        |> mes("[Scientist]")
        |> mes("I mean, come on!")
        |> mes("I shouldn't have to")
        |> mes("carry his workload!")
        |> close()

      _ ->
        close(ctx)
    end
  end
end
