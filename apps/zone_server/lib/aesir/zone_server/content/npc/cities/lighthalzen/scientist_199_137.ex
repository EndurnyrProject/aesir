defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Scientist199137 do
  @moduledoc """
  Responds to visitors inside the restricted Regenschirm laboratory.

  ## Behavior

  - Warns disguised staff away from volatile chemicals.
  - Calls for guards and warps undisguised visitors out.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 199,
        y: 137,
        dir: 3,
        sprite: 865,
        name: "Scientist",
        scope: :shared,
        unique_name: "Scientist#li_03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2241)) and Rathena.truthy?(is_equipped(ctx, 2243)) do
      ctx
      |> mes("[Scientist]")
      |> mes("Whoa whoa~!")
      |> mes("Please! Don't")
      |> mes("touch anything!")
      |> mes("I'm dealing with highly")
      |> mes("volatile chemicals here!")
      |> close()
    else
      ctx
      |> mes("[Scientist]")
      |> mes("Guards! Hurry,")
      |> mes("there's someone")
      |> mes("here, and I think")
      |> mes("it's one of those crazy")
      |> mes("stalkers! Why, why me?!")
      |> emotion(:surprise)
      |> close()
      |> warp("lhz_in01", 33, 224)
    end
  end
end
