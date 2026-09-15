defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.ManukPiom293203 do
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
        x: 293,
        y: 203,
        dir: 3,
        sprite: 454,
        name: "Manuk Piom",
        scope: :shared,
        unique_name: "Manuk Piom#tre4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Manuk Piom]")
      |> mes("Hey, Be careful!")
      |> mes("This mineral is Bradium which is the life of our tribe.")
      |> mes("If you don't handle the stone carefully, you'll be in trouble!")
      |> close()
    else
      ctx
      |> mes("[Manuk Piom]")
      |> mes("Bmm ish di sd")
      |> mes("Fii sd ani s a d s k ds ")
      |> mes("Ti h is so so pd")
      |> close()
    end
  end
end
