defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.ManukGaltun194189 do
  @moduledoc """
  Greets visitors who can understand the local Manuk language.

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
        x: 194,
        y: 189,
        dir: 3,
        sprite: 450,
        name: "Manuk Galtun",
        scope: :shared,
        unique_name: "Manuk Galtun#tre3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Manuk Galtun]")
      |> mes("Welcome to Manuk.")
      |> mes("How can I help you?")
      |> close()
    else
      ctx
    end
  end
end
