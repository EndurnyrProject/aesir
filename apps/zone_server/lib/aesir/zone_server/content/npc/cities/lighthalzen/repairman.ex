defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Repairman do
  @moduledoc """
  Responds to visitors inside the restricted Regenschirm laboratory.

  ## Behavior

  - Discusses damaged equipment with disguised staff.
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
        x: 217,
        y: 121,
        dir: 3,
        sprite: 851,
        name: "Repairman",
        scope: :shared,
        unique_name: "Repairman#li_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2241)) and Rathena.truthy?(is_equipped(ctx, 2243)) do
      ctx
      |> mes("[Repairman]")
      |> mes("No wonder these things")
      |> mes("break all the time! These")
      |> mes("machines have been totally")
      |> mes("abused! Ugh, there's no")
      |> mes("appreciation for all of this")
      |> mes("convenient technology...")
      |> next()
      |> mes("[Repairman]")
      |> mes("Yeah, all of this lab")
      |> mes("equipment is really sensitive,")
      |> mes("not to mention expensive. If")
      |> mes("you ever handle this stuff, you")
      |> mes("need to be extra cautious.")
      |> close()
    else
      ctx
      |> mes("[Repairman]")
      |> mes("Hey, you don't work--")
      |> mes("G-guards! Hurry! There's")
      |> mes("somebody over here!")
      |> emotion(:surprise)
      |> close()
      |> warp("lhz_in01", 33, 224)
    end
  end
end
