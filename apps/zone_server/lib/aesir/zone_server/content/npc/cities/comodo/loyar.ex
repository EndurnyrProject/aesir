defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Loyar do
  @moduledoc """
  Shares one of Loyar's observations about the Comodo Casino.

  ## Behavior

  - Randomly discusses leaving on time, the casino's atmosphere, or sensible betting limits.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in02",
        x: 174,
        y: 126,
        dir: 4,
        sprite: 83,
        name: "Loyar",
        scope: :shared,
        unique_name: "Loyar#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Loyar]")
      |> mes("Comodo Casino's interior")
      |> mes("design is so pleasing to the")
      |> mes("eyes, so clean and simple.")
      |> mes("The atmosphere here is perfect,")
      |> mes("and it makes me want to play ")
      |> mes("some more. Alright, let's go!")
      |> next()

    case Enum.random(1..3) do
      1 -> discuss_leaving(ctx)
      2 -> discuss_atmosphere(ctx)
      3 -> discuss_betting(ctx)
      _ -> ctx
    end
  end

  defp discuss_leaving(ctx) do
    ctx
    |> mes("[Loyar]")
    |> mes("Hmm... Maybe I better")
    |> mes("go home soon. I didn't")
    |> mes("spend all the money that")
    |> mes("I set aside for gambling")
    |> mes("quite yet, but it's not a good")
    |> mes("idea to stay out too long.")
    |> close()
  end

  defp discuss_atmosphere(ctx) do
    ctx
    |> mes("[Loyar]")
    |> mes("I have to admit, the")
    |> mes("atmosphere of this place")
    |> mes("is exciting and addictive.")
    |> mes("Even when you're tired, the")
    |> mes("energy of this place just")
    |> mes("gets into you, you know?")
    |> next()
    |> mes("[Loyar]")
    |> mes("Although this kind of place")
    |> mes("may encourage people with")
    |> mes("serious gambling problems,")
    |> mes("it's much nicer to gamble")
    |> mes("here than in a place that's")
    |> mes("dirtier and more questionable.")
    |> close()
  end

  defp discuss_betting(ctx) do
    ctx
    |> mes("[Loyar]")
    |> mes("Whoa whoa whoa...")
    |> mes("Why did that guy make")
    |> mes("that bet? What an amateur...")
    |> mes("Er, I guess you don't know")
    |> mes("too much about this game.")
    |> mes("As for me, I'm just a fan~")
    |> next()
    |> mes("[Loyar]")
    |> mes("I'm a big fan of a lot")
    |> mes("of these games, but I'll")
    |> mes("admit that I'm an even bigger")
    |> mes("fan of winning! Still, I have")
    |> mes("enough sense to stay out of")
    |> mes("those high stakes games.")
    |> close()
  end
end
