defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Benknee225129 do
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
        x: 225,
        y: 129,
        dir: 5,
        sprite: 449,
        name: "Benknee",
        scope: :shared,
        unique_name: "Benknee#ep13_2_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Benknee]")
      |> mes("Huh? Who?? Who are you??")
      |> mes("Oh, you are not a fairy.")
      |> mes("I thought you were a fairy thing.")
      |> mes("Anyway, who are you? Can you speak?")
      |> close()
    else
      ctx
      |> mes("[Benknee]")
      |> mes("Bao j pj a sd")
      |> mes("Gi oh as d")
      |> mes("Ya sd Yrt sd ad")
      |> mes("Bq we ojj jd")
      |> close()
    end
  end
end
