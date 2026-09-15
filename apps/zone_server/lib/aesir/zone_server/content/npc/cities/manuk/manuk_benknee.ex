defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.ManukBenknee do
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
        x: 253,
        y: 173,
        dir: 3,
        sprite: 449,
        name: "Manuk Benknee",
        scope: :shared,
        unique_name: "Manuk Benknee#tre5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Manuk Benknee]")
      |> mes("Can you see that statue?")
      |> mes("He's the Hwergelmir, who is like a legend for us Sapha.")
      |> mes("He was a real majestic and brave man.")
      |> close()
    else
      ctx
      |> mes("[Manuk Piom]")
      |> mes("Ys oadj oa s d")
      |> mes("Bni ii osd jo as das")
      |> mes("Qa oj df isd oo o")
      |> close()
    end
  end
end
