defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.DowbowRyuei do
  @moduledoc """
  Asks the player to choose between being cool and being realistic.

  ## Behavior

  - Responds enthusiastically to 'Uber-Cool' and explains his preference for dreaming when 'Reality' is chosen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 125,
        y: 40,
        dir: 3,
        sprite: 843,
        name: "Dowbow Ryuei",
        scope: :shared,
        unique_name: "Dowbow Ryuei#ryusei"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dowbow Ryuei]")
      |> mes("Just out of, oh I dunno,")
      |> mes("curiosity, which word do")
      |> mes("you like better? ''Uber-Cool''")
      |> mes("or ''Reality?'' Pick one~")
      |> next()
      |> select(["Uber-Cool", "Reality"])

    if choice == 1 do
      ctx
      |> mes("[Dowbow Ryuei]")
      |> mes("Oh yeah? Me too!")
      |> mes("Yeah, we got the same")
      |> mes("outlook on life. If you don't")
      |> mes("mind, I'd like to shake")
      |> mes("your hand, adventurer.")
      |> emotion(:best)
      |> close()
    else
      ctx
      |> mes("[Dowbow Ryuei]")
      |> mes("Reality, eh?")
      |> mes("Well, I agree that")
      |> mes("being realistic has its")
      |> mes("perks, I'm more of a dreamer.")
      |> close()
    end
  end
end
