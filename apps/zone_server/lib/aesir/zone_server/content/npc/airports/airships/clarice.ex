defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Clarice do
  @moduledoc """
  Invites international airship passengers to gamble Apples in a dice game.

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
      %{map: "airplane_01", x: 33, y: 68, dir: 4, sprite: 74, name: "Clarice", scope: :shared}
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.Applegamble
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Clarice]")
      |> mes("Hi, I'm Clarice~")
      |> mes("How would you like")
      |> mes("to wager some Apples")
      |> mes("in a friendly game of Dice?")
      |> next()
      |> Applegamble.call(["Clarice"])

    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
