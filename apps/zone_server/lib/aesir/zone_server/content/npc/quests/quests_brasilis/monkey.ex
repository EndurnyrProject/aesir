defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Monkey do
  @moduledoc """
  Monkey gives the adventurer grapes for the Guarana Candy quest.

  ## Behavior

  - Gives quest participants grapes and advances the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_fild01",
        x: 245,
        y: 52,
        dir: 3,
        sprite: 111,
        name: "Monkey",
        scope: :shared,
        unique_name: "Monkey#bra"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :brazil_gua, 0) == 8 do
      ctx =
        ctx
        |> mes("[Monkey]")
        |> mes("What is it??!!")
        |> mes("We don't tolerate humans? Get out~!!")
        |> next()
        |> mes("[Monkey]")
        |> mes("Nono... wait.... that scent!!")
        |> mes("I can smell Jaguar from you, who are you?")
        |> mes("Gosh, maybe there's no jaguar without fur and weird shape!")
        |> next()

      {ctx, _} =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("........................")
        |> mes("Are you saying that I look like an animal?!?!")
        |> next()
        |> mes("[Monkey]")
        |> mes("Uh? Aren't you a jaguar?")
        |> next()
        |> mes("[Monkey]")
        |> mes("Ahhha. Jaguar send you to me, right?? kkkikkki")
        |> mes("But you don't look like guarana kid.")
        |> next()
        |> select(["I've come here to help him."])

      ctx =
        ctx
        |> mes("[Monkey]")
        |> mes("I heard guarana kid became lonely, is he?")
        |> mes("We are experts in acrobatic acts, does kid like it?? kkkickkksk!")
        |> next()
        |> mes("[Monkey]")
        |> mes("Give this branch of grapes to guarana kid.")
        |> mes(
          "We will make him have fun during the whole night whenever he comes to us!! kkkickkksk!"
        )
        |> next()
        |> mes("- You get a bunch of grapes from Monkey. -")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Good~ Now it's time to go back to the kid~!!")
      |> set_char_var(:brazil_gua, 9)
      |> changequest(2198, 2199)
      |> close()
    else
      ctx |> mes("[Monkey]") |> mes("kkkickkksk!") |> close()
    end
  end
end
