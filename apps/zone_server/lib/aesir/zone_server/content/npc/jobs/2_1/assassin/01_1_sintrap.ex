defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.M011Sintrap do
  @moduledoc """
  Booby trap on the Assassin job test floor that sends careless applicants back.

  ## Behavior

  - While the Beholder's traps are armed, announces the trapped player, resets the test
    progress, sends the player back, clears the test monsters, and reopens the standby room.

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
    if get_npc_var_of(ctx, "DisableTraps", "Beholder#ASNTEST", 0) < 1 do
      ctx
      |> mapannounce(
        "in_moc_16",
        "#{char_name(ctx, 0)}, you're trapped. You will be sent back.",
        1
      )
      |> set_char_var(:ASSIN_Q, 2)
      |> warp("in_moc_16", 19, 161)
      |> donpcevent("Beholder#ASNTEST::OnResetmob")
      |> donpcevent("Standby Room#ASNTEST::OnStart")
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
