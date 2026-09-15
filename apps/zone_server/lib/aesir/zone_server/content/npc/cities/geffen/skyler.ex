defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Skyler do
  @moduledoc """
  Directs visitors to Eric and describes his magical Ear Muffs project.

  ## Behavior

  - Explains Eric's project to visitors who do not know him.
  - Encourages visitors already looking for Eric to help him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "geffen_in", x: 59, y: 61, dir: 1, sprite: 61, name: "Skyler", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Skyler]")
      |> mes("Hello hello.")
      |> mes("You're not looking")
      |> mes("for Eric, are you?")
      |> next()
      |> select(["Eric? Who's that?", "Yes. Yes, I am."])

    if choice == 1 do
      explain_eric(ctx)
    else
      direct_to_eric(ctx)
    end
  end

  defp explain_eric(ctx) do
    ctx
    |> mes("[Skyler]")
    |> mes(
      "Oh, I see. He's just some guy in the room to the left of me. He's always working on some sort of project."
    )
    |> next()
    |> mes("[Skyler]")
    |> mes(
      "Something to do with these magic sort of Ear Muffs. I guess he's been looking for investors to help him finish building whatever he's making."
    )
    |> close()
  end

  defp direct_to_eric(ctx) do
    ctx
    |> mes("[Skyler]")
    |> mes(
      "Oh, alright. You can find Eric in the room to the left of me. He'll probably be happy to know someone is interested in what he's trying to build."
    )
    |> next()
    |> mes("[Skyler]")
    |> mes(
      "From what I remember, he seemed really discouraged, thinking he'd never be able to finish his little project."
    )
    |> next()
    |> mes("[Skyler]")
    |> mes("I'm glad to hear you've come this way to help out that young fellow.")
    |> close()
  end
end
