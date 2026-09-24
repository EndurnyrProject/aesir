defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.Barcardi do
  @moduledoc """
  Congratulates applicants who cross the hiding test room and sends them to the Guildmaster's maze.

  ## Behavior

  - Stops the hiding test timer and monsters, advances the quest, and warps the player onward.

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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 87,
        y: 48,
        dir: 2,
        sprite: 725,
        name: "Barcardi",
        scope: :shared,
        unique_name: "Barcardi#ASN",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx
    |> donpcevent("timestopper#1::OnDisable")
    |> donpcevent("Thomas#ASNTEST::OnDisable")
    |> mes("[Barcardi]")
    |> mes("Oh! Congratulations!")
    |> mes("You may now proceed to our Guildmaster's room. Good luck!!")
    |> close()
    |> set_char_var(:ASSIN_Q, 5)
    |> changequest(8004, 8005)
    |> warp("in_moc_16", 181, 183)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
