defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.RekenberGuard23132 do
  @moduledoc """
  Guards a restricted Regenschirm laboratory area.

  ## Behavior

  - Allows disguised visitors to remain and warns them about intruders.
  - Warps undisguised visitors out after confronting them.

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
        x: 23,
        y: 132,
        dir: 3,
        sprite: 867,
        name: "Rekenber Guard",
        scope: :shared,
        unique_name: "Rekenber Guard#li02",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: handle_touch(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp handle_touch(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2241)) and Rathena.truthy?(is_equipped(ctx, 2243)) do
      ctx
      |> mes("[Rekenber Guard]")
      |> mes("Keep your eyes open.")
      |> mes("I've heard rumors that some")
      |> mes("adventurers from Rune-Midgarts")
      |> mes("are trying to sneak into here!")
      |> mes("I know the security here is")
      |> mes("pretty much fail sure, but...")
      |> close()
    else
      ctx
      |> mes("[Rekenber Guard]")
      |> mes("This area is restricted")
      |> mes("to the public! Who are you")
      |> mes("and how did you get in here?!")
      |> mes("Hey, I need backup right away!")
      |> close()
      |> warp("lhz_in01", 33, 224)
    end
  end
end
