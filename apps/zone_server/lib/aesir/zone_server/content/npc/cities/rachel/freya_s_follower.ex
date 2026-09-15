defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FreyaSFollower do
  @moduledoc """
  Explains the roles of Freya's followers, priests, and high priests.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 201,
        y: 174,
        dir: 3,
        sprite: 926,
        name: "Freya's Follower",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Freya's Follower]")
    |> mes("All of Arunafeltz believes")
    |> mes("in the goddess Freya, but")
    |> mes("there are those of us that")
    |> mes("are more seriously involved")
    |> mes("in adoration and worship.")
    |> next()
    |> mes("[Freya's Follower]")
    |> mes("First, there are ''Freya's")
    |> mes("Followers,'' men and women")
    |> mes("like me that dress in holy masks")
    |> mes("and garments. I realize that our")
    |> mes("dress may seem a bit peculiar")
    |> mes("to you, but that is our way.")
    |> next()
    |> mes("[Freya's Follower]")
    |> mes("Then, there are the Priests")
    |> mes("who dress in clean, white")
    |> mes("flowing robes. They work in")
    |> mes("the temple and serve the")
    |> mes("community as religious leaders.")
    |> next()
    |> mes("[Freya's Follower]")
    |> mes("Among these priests are")
    |> mes("the elite High Priests that")
    |> mes("directly assist our pope.")
    |> mes("They wear more colorful")
    |> mes("clothes as a sign of their")
    |> mes("higher status in Rachel.")
    |> next()
    |> mes("[Freya's Follower]")
    |> mes("All of us work tirelessly")
    |> mes("to bring prosperity to")
    |> mes("Arunafeltz, and to carry")
    |> mes("out the teachings of our")
    |> mes("beloved goddess Freya.")
    |> close()
  end
end
