defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.MasterAssist do
  @moduledoc """
  Guildmaster's assistant who redirects applicants to the Guildmaster.

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
        x: 186,
        y: 81,
        dir: 1,
        sprite: 55,
        name: "Master Assist",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Assistent Gayle Maroubitz]")
    |> mes(
      "Sorry, but I'm not in charge of job changes. Go to the Guildmaster, as he has told you."
    )
    |> close()
  end
end
