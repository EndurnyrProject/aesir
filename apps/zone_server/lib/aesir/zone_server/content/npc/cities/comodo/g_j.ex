defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.GJ do
  @moduledoc """
  Shares G. J.'s thoughts on earning and managing money instead of gambling.

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
        x: 172,
        y: 105,
        dir: 4,
        sprite: 86,
        name: "G . J",
        scope: :shared,
        unique_name: "G . J#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[G . J]")
    |> mes("The more I think about it,")
    |> mes("it seems easier to become")
    |> mes("rich by working, saving, and")
    |> mes("making wise investments than")
    |> mes("to, you know... Rely on some")
    |> mes("kind of huge jackpot prize.")
    |> next()
    |> mes("[G . J]")
    |> mes("Gambling seems fun, but")
    |> mes("it seems smarter to make")
    |> mes("money in other ways. Sure,")
    |> mes("working hard is no fun, but")
    |> mes("there are ways to use your money to make more of it, right?")
    |> next()
    |> mes("[G . J]")
    |> mes("There's also the matter of")
    |> mes("being smart and responsible")
    |> mes("about your money--I mean, you're more likely to blow all your cash")
    |> mes("if you win it, right? Yeah, you")
    |> mes("gotta be wise about it all...")
    |> close()
  end
end
