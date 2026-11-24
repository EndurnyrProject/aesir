defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Hugeltree do
  @moduledoc """
  A comforting tree begins the Memory Quest and reacts to its progress.

  ## Behavior

  - Starts the quest for eligible adventurers and reveals a chill during their investigation.

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
    spawn: [
      %{
        map: "hugel",
        x: 198,
        y: 169,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#HugelTree",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    memory = get_char_var(ctx, :hg_memory, 0)

    cond do
      base_level(ctx) > 49 and not Rathena.truthy?(memory) ->
        ctx |> set_char_var(:hg_memory, 1) |> setquest(8057) |> comfort()

      base_level(ctx) > 49 and memory == 6 ->
        ctx
        |> specialeffect2(:beginspell5)
        |> mes("^3355FFWhat's this strange")
        |> mes("feeling of dread?")
        |> mes("This peculiar chill...")
        |> mes("It's almost as if you")
        |> mes("were in Niflheim...^000000")
        |> close()

      true ->
        comfort(ctx)
    end
  end

  defp comfort(ctx) do
    ctx
    |> mes("^3355FFFor some reason, you")
    |> mes("feel very warm, safe,")
    |> mes("and secure near this")
    |> mes("tree. Just being near")
    |> mes("it brings you a sense")
    |> mes("of overwhelming comfort.^000000")
    |> close()
  end
end
