defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.ManukGaltun do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "manuk",
        x: 103,
        y: 354,
        dir: 5,
        sprite: 450,
        name: "Manuk Galtun",
        scope: :shared,
        unique_name: "Manuk Galtun#door1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Manuk Galtun]")
      |> mes("Here is Manuk where the Sapha who is descendant of Hwergelmir lives.")
      |> close()
    else
      ctx |> mes("[Manuk Galtun]") |> mes("Zd sng pps fsr") |> close()
    end
  end
end
