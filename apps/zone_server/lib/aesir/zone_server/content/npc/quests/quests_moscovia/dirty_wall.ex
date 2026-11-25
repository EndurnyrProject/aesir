defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.DirtyWall do
  @moduledoc """
  A wall bearing a clue to the treasure box.

  ## Behavior

  - Reveals a clue and advances the treasure hunt.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "treasure01",
        x: 98,
        y: 119,
        dir: 0,
        sprite: 111,
        name: "Dirty Wall",
        scope: :shared,
        unique_name: "Dirty Wall#rus39"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :rhea_rus_main, 0) >= 22 and get_char_var(ctx, :rhea_rus_main, 0) < 26 do
      ctx =
        ctx
        |> mes("- Something is engraved on the wall -")
        |> next()
        |> mes(
          "- ^ff0000Her... careful.. Mermaid's song.. sleeping.. the eyes.. protect your.. mirror^000000 -"
        )
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...What is this talking about...?")

      ctx =
        if get_char_var(ctx, :rhea_rus_main, 0) == 22 do
          set_char_var(ctx, :rhea_rus_main, 23)
        else
          ctx
        end

      close(ctx)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
