defmodule Aesir.ZoneServer.Content.Npc.Cities.Yuno.JunoDespot do
  @moduledoc """
  Shares rumors about Pharaoh and a rare warning about virtual reality.

  ## Behavior

  - Usually warns the player about Pharaoh.
  - On a rare roll, warns about virtual reality and warps the player to Prontera.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 343,
        y: 68,
        dir: 4,
        sprite: 730,
        name: "Juno Despot",
        scope: :shared,
        unique_name: "Juno Despot#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Ninno]")

    if Enum.random(1..1000) == 1 do
      reveal_reality(ctx)
    else
      warn_about_pharaoh(ctx)
    end
  end

  defp reveal_reality(ctx) do
    ctx
    |> mes(
      "You are very lucky to have me tell you this story. This only happens by ^FF33551 out of a 1,000 chance^000000."
    )
    |> next()
    |> mes("[Ninno]")
    |> mes(
      "This world you are experiencing is actually fabricated! It's time for you to see reality for what it is!"
    )
    |> next()
    |> mes("[Ninno]")
    |> mes("Open your eyes! Stop being manipulated by virtual reality!")
    |> close()
    |> warp("prontera", 182, 206)
  end

  defp warn_about_pharaoh(ctx) do
    ctx
    |> mes(
      "Have you ever heard of an Egyptian king who was once believed to be a son of a god? His name is ^3355FFPharoah^000000."
    )
    |> next()
    |> mes("[Ninno]")
    |> mes(
      "He was rumored to be a high sorcerer that used his power to curse innocents. It is said that he is still around, placing his curses on people."
    )
    |> next()
    |> mes("[Ninno]")
    |> mes("As an adventurer, it's possible that you may see him in your travels. Be careful...")
    |> close()
  end
end
