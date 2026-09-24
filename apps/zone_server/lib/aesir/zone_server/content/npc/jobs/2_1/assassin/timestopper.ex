defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.Timestopper do
  @moduledoc """
  Controller for the time limit and no-kill rule of the Assassin hiding test.

  ## Behavior

  - Ends the hiding test through Thomas when the time limit runs out.
  - Sends applicants who kill a test monster back to the start of the hiding test and
    removes the remaining test monsters.

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
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer187000", ctx) do
    ctx
    |> donpcevent("Thomas#ASNTEST::OnDisable")
    |> stopnpctimer()
  end

  def on_event("OnDisable", ctx), do: stopnpctimer(ctx)

  def on_event("OnMyMobDead", ctx) do
    ctx
    |> mapannounce(
      "in_moc_16",
      "Hey, what the hell was that?! I told you: No killing monsters!",
      1
    )
    |> mapannounce("in_moc_16", "I'm bringing you back... *Sigh...*", 1)
    |> set_char_var(:ASSIN_Q, 3)
    |> warp("in_moc_16", 87, 102)
    |> killmonster("in_moc_16", "timestopper#1::OnMyMobDead")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
