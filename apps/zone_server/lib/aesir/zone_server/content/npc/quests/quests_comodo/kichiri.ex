defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Kichiri do
  @moduledoc """
  Kichiri talks about Comodo and its legendary cheese.

  ## Behavior

  - Advances the doomed swords quest after complaining about Magatu.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 169,
        y: 284,
        dir: 4,
        sprite: 98,
        name: "Kichiri",
        scope: :shared,
        unique_name: "Kichiri#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        7 ->
          ctx
          |> mes("[Kichiri]")
          |> mes("Freakin' ^3355FFMagatu^000000...!")
          |> mes("Can he talk about anything else")
          |> mes("aside from Comodo Cheese?")
          |> mes("I don't see why he's so excited")
          |> mes("about the stuff! Everyone knows")
          |> mes("it's just an old wive's tale.")
          |> next()
          |> mes("[Kichiri]")
          |> mes("Would you do")
          |> mes("me a favor and get")
          |> mes("Magatu to shut up?")
          |> mes("I just want to drink")
          |> mes("my alcohol in peace!")
          |> set_char_var(:dmdswrd_Q, 8)

        8 ->
          ctx
          |> mes("[Kichiri]")
          |> mes("Cripes! Now Magatu's")
          |> mes("got me wondering! I mean,")
          |> mes("just because I've never seen")
          |> mes("Comodo Cheese doesn't mean")
          |> mes("it doesn't exist, right? Curses! Now I'm thinking about it too!")

        _ ->
          ctx
          |> mes("[Kichiri]")
          |> mes("There's more to do than")
          |> mes("gambling in Comodo, you")
          |> mes("know. Sometimes, I love")
          |> mes("to watch the Dancers on")
          |> mes("stage in the middle of the")
          |> mes("village. They're so glamorous~")
          |> next()
          |> mes("[Kichiri]")
          |> mes("I hear that the Dance")
          |> mes("Academy only accepts female")
          |> mes("Archers to become prospective")
          |> mes("Dancers. I guess that makes")
          |> mes("sense--they're tone and fit,")
          |> mes("but not musclebound either...")
      end

    close(ctx)
  end
end
