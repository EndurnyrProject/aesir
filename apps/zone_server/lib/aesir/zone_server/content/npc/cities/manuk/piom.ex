defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Piom do
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
    spawn: [%{map: "manuk", x: 100, y: 100, dir: 3, sprite: 454, name: "Piom", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Piom]")
      |> mes("You are... tiny. But you don't seem like a Fairy.")
      |> mes("As long as you are not a damned Fairy,")
      |> mes("then you are not our foe!")
      |> mes("In this world, there are only friends or foe!")
      |> close()
    else
      ctx
      |> mes("[Piom]")
      |> mes("As our wi nueo woud bus")
      |> mes("Gw pii rooop pishe")
      |> mes("Fw iusbn podim bn usow ")
      |> mes("Psbh io whe pasn jd")
      |> close()
    end
  end
end
