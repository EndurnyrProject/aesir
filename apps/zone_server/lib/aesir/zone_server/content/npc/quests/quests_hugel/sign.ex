defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Sign do
  @moduledoc """
  Displays the Odin Shrine expedition recruitment notice or the magician community notice.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hugel", x: 91, y: 152, dir: 1, sprite: 837, name: "Sign", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    odin = get_char_var(ctx, :hg_odin, 0)
    ctx = ctx |> mes("**Recruitment Notice**") |> mes(" ")

    if odin < 60 do
      ctx =
        ctx
        |> mes("We are now hiring recruits")
        |> mes("for the Odin Shrine Expedition.")
        |> mes(" ")
        |> mes("- Shrine Expedition Dept.")

      ctx = if Rathena.truthy?(odin), do: ctx, else: set_char_var(ctx, :hg_odin, 1)
      close(ctx)
    else
      ctx
      |> mes("Join our magician")
      |> mes("community, and make")
      |> mes("all your days a festival!")
      |> mes(" ")
      |> mes("- Hugel Magician Community")
      |> close()
    end
  end
end
