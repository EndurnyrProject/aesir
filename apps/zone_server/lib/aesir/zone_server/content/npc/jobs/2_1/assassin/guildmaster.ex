defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.Guildmaster do
  @moduledoc """
  Greets applicants entering the Guildmaster's maze of the Assassin job test.

  ## Behavior

  - Saves the player's respawn point at the maze entrance and explains the maze.
  - Announces the next volunteer when the Maze Assistant signals an entrance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

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
    |> savepoint("in_moc_16", 167, 110)
    |> mes("[Guildmaster]")
    |> mes("Welcome. ")
    |> mes(
      "This place is called the 'Guildmaster's room,' the deepest place in the Assassin guild."
    )
    |> next()
    |> mes("[Guildmaster]")
    |> mes(
      "I'm going to give you a simple test. Please find your way through this maze and come to me. It is this maze that protects our guild from intruders."
    )
    |> next()
    |> mes("[Guildmaster]")
    |> mes("I look forward")
    |> mes("to meeting you")
    |> mes("at the end of maze.")
    |> close()
  end

  def on_event("OnCast", ctx) do
    mapannounce(ctx, "in_moc_16", "...Next volunteer, please come in.", 1)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
