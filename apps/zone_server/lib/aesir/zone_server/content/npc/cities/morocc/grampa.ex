defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.Grampa do
  @moduledoc """
  Shares his belief that Osiris is entombed in Morocc’s largest pyramid.

  ## Credits

  - Original from rAthena, authors and Contributors
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
        map: "moc_ruins",
        x: 128,
        y: 153,
        dir: 0,
        sprite: 61,
        name: "Grampa",
        scope: :shared,
        unique_name: "Grampa#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Scholar]")
    |> mes(
      "I've devoted my life to researching the mysterious pyramids near Morocc. I haven't been able to concretely confirm anything yet, but..."
    )
    |> next()
    |> mes("[Old Scholar]")
    |> mes(
      "I'm sure that the largest pyramid contains the tomb of the ancient king, Osiris! I'm willing to stake my life on it!"
    )
    |> close()
  end
end
