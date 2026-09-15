defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.FistMaster do
  @moduledoc """
  Explains the patience and discipline required to master the Claw of Dragon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "louyang",
        x: 276,
        y: 136,
        dir: 4,
        sprite: 819,
        name: "Fist master",
        scope: :shared,
        unique_name: "Fist master#lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Zhiang Xiau Ji]")
    |> mes("Finally...")
    |> mes("I have mastered")
    |> mes("the 'Claw of Dragon!'")
    |> next()
    |> mes("[Zhiang Xiau Ji]")
    |> mes(
      "Although there are eight basic steps, I had to learn the history of this art, and meditate, focusing on my spiritual improvement,"
    )
    |> mes("for three years.")
    |> next()
    |> mes("[Zhiang Xiau Ji]")
    |> mes(
      "After that, my master finally started to give me the physical training so I could use the eight steps of the Claw of Dragon. I've devoted myself to this art for thirty years."
    )
    |> next()
    |> mes("[Zhiang Xiau Ji]")
    |> mes("I'm very proud that I've")
    |> mes(
      "mastered this art ten years earlier than I expected. Now, I need to study this form and improve it by correcting its weak points and enhancing its strengths."
    )
    |> next()
    |> mes("[Zhiang Xiau Ji]")
    |> mes("I guess that would take me about ten years. But I'm not disheartened by that at all.")
    |> next()
    |> mes("[Zhiang Xiau Ji]")
    |> mes(
      "When you're learning a martial art, you can't rush yourself and learn everything in a short period of time. It's impossible! Plus, that isn't the essence of art..."
    )
    |> close()
  end
end
