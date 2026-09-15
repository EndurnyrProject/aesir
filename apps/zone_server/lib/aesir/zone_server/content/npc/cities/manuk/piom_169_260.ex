defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Piom169260 do
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
        x: 169,
        y: 260,
        dir: 3,
        sprite: 455,
        name: "Piom",
        scope: :shared,
        unique_name: "Piom#ep13_2_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Piom]")
      |> mes("We, Saphas are always together!")
      |> mes("Wherever we are. We are always connected to each other.")
      |> mes("I don't know where you are from but, you should learn our spirits.")
      |> close()
    else
      ctx
      |> mes("[Piom]")
      |> mes("Ng go oois yus dd")
      |> mes("You ii iaao nfb ud")
      |> mes("Wqq ifn isp did")
      |> mes("Uy ydf sd fs wee")
      |> mes("Mgg gf fs d ff")
      |> close()
    end
  end
end
