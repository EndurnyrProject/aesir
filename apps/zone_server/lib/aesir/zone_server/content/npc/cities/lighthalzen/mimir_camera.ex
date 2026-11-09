defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.MimirCamera do
  @moduledoc """
  Handles a hidden interaction that photographs male Assassins.

  ## Behavior

  - Shows the camera interaction only to male Assassin characters.

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
        x: 138,
        y: 47,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mimir_camera",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: photograph_assassin(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)

  defp photograph_assassin(ctx) do
    if base_job(ctx) == :assassin and sex(ctx) == 1 do
      ctx
      |> mes("^3355FF*Click*^000000")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What the...?")
      |> mes("That sound. Did...")
      |> mes("Did someone just")
      |> mes("take my picture?")
      |> close()
    else
      ctx
    end
  end
end
