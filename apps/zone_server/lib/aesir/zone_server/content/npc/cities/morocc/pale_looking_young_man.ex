defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.PaleLookingYoungMan do
  @moduledoc """
  Recounts the terrifying destruction of Morocc.

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
        x: 94,
        y: 117,
        dir: 0,
        sprite: 48,
        name: "Pale Looking Young Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Pale-looking Young Man]")
    |> mes(
      "... That day... I saw the bloody moon in the sky. It was too silent that it felt so spooky."
    )
    |> next()
    |> mes("[Pale-looking Young Man]")
    |> mes(
      "Not even a whistle of dry wind, and the air so heavy and stuffy, I could hardly breathe."
    )
    |> next()
    |> mes("[Pale-looking Young Man]")
    |> mes(
      "But then, Bang! It was right that time that I saw the enormous amount of smoke rising up at the Castle of Morocc with an earsplitting sound."
    )
    |> next()
    |> mes("[Pale-looking Young Man]")
    |> mes(
      "All happened so fast. The Oasis of the Castle was all dried up and the town was destroyed. And... and that voice... I heard a voice."
    )
    |> next()
    |> mes("[Pale-looking Young Man]")
    |> mes(
      "Blood... Blood is what it takes to pay for the soul... and that dark sound of laughter..."
    )
    |> mes("Aah!!! It's... It's still ringing in my ears!!! Aahhhhh!!!!")
    |> next()
    |> mes("- It'd be better not to disturb him anymore -")
    |> close()
  end
end
