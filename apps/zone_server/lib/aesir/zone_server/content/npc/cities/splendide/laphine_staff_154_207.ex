defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.LaphineStaff154207 do
  @moduledoc """
  Explains how the camp bar supports Laphine soldiers.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped and the ep13_2_rhea gate is complete; otherwise
    responds in untranslated language.

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
        map: "spl_in01",
        x: 154,
        y: 207,
        dir: 5,
        sprite: 440,
        name: "Laphine Staff",
        scope: :shared,
        unique_name: "Laphine Staff#ep13_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[Laphine Staff]")
      |> mes("his camp serves a military purpose. But we also have a need for bars.")
      |> next()
      |> mes("[Laphine Staff]")
      |> mes("How else can a soldier release stress if not through drinking...")
      |> next()
      |> mes("[Laphine Staff]")
      |> mes(
        "We are here to support the laphine soldier by giving good drinks and entertainment."
      )
      |> close()
    else
      ctx
      |> mes("[Laphine Staff]")
      |> mes("NorVerNuff Ee Re!")
      |> mes("remuDurOdes Mu AshFus~!")
      |> mes("OdesTalWeh Ur??? ")
      |> close()
    end
  end
end
