defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.JawaiiResident165121 do
  @moduledoc """
  Sings about Jawaii and describes the town stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 165,
        y: 121,
        dir: 1,
        sprite: 724,
        name: "Jawaii Resident",
        scope: :shared,
        unique_name: "Jawaii Resident#desc3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Iwa Iwa]")
    |> mes("Jawaii~")
    |> mes("Jawa~ii~")
    |> mes("Where you can")
    |> mes("find happiness~")
    |> next()
    |> mes("[Iwa Iwa]")
    |> mes(
      "Oh, isn't it beautiful? You don't have to do anything other than relax and breathe in the peaceful atmosphere. That's one of the"
    )
    |> mes("best things about Jawaii.")
    |> next()
    |> mes("[Iwa Iwa]")
    |> mes("Ooh! Sometimes we hold")
    |> mes("concerts on this stage. If you're good at singing, why don't you")
    |> mes("go up on stage and sing")
    |> mes("a song for us?")
    |> next()
    |> mes("[Iwa Iwa]")
    |> mes("Jawaii~")
    |> mes("Jawa~ii~")
    |> mes("Where you can")
    |> mes("find happiness~")
    |> close()
  end
end
