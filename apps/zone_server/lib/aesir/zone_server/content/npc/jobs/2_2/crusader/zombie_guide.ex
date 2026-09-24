defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.ZombieGuide do
  @moduledoc """
  Reminds candidates entering the Crusader purification arena of its rules and time limit.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - Kisuka
    - Capuche
    - Komurka
    - massdriller
    - DracoRPG
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx
    |> mes("[Bliant Piyord]")
    |> mes("Go forth and defeat all")
    |> mes("the monsters that appear.")
    |> mes("You will not pass if any")
    |> mes("are remaining.")
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("You will be given")
    |> mes("4 minutes. Go forth")
    |> mes("and do your best...")
    |> close()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
