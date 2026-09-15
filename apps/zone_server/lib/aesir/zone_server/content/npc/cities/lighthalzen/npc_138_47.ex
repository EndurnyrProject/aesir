defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Npc13847 do
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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: photograph_assassin(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp photograph_assassin(ctx) do
    if base_job(ctx) == :assassin and sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
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
