defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.ManukPiom do
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
        x: 99,
        y: 334,
        dir: 5,
        sprite: 460,
        name: "Manuk Piom",
        scope: :shared,
        unique_name: "Manuk Piom#tre1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Manuk Piom]")
      |> mes("Galtuns are brave Sapha warriors.")
      |> mes("I am a Piom class which is general labor.")
      |> next()
      |> mes("[Manuk Piom]")
      |> mes(
        "By virtue of the braveness of the Galtun, we can stand for a long time from the diversions of the Laphine."
      )
      |> mes("We always appreciate their efforts.")
      |> close()
    else
      ctx
      |> mes("[Manuk Piom]")
      |> mes("H dn i sid p sd ")
      |> mes("Nd isjd sapd j s id")
      |> mes("Bsi o ps dkm jgf")
      |> mes("Eo oo ptr n sid")
      |> close()
    end
  end
end
