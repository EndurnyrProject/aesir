defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.FemaleResearcher do
  @moduledoc """
  A researcher appears in the burning laboratory vision.

  ## Behavior

  - The player passes through her at the relevant quest stage; other stages are warped away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "que_ba",
        x: 257,
        y: 39,
        dir: 3,
        sprite: 744,
        name: "Female Researcher",
        scope: :shared,
        unique_name: "Female Researcher#bpast"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :barmunt_crow, 0)

    cond do
      progress < 4 ->
        warp(ctx, "ama_dun03", 119, 110)

      progress == 4 ->
        encounter_researcher(ctx)

      true ->
        warp(ctx, "yuno_in04", 100, 3)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp encounter_researcher(ctx) do
    ctx =
      ctx
      |> mes(
        "^660000While trying to remember what happened, you encounter a woman who passes by you. You instinctively reach for her shoulder to get her attention.^000000"
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ahchoo! Ahchoo! Gosh...")
      |> mes("Hey, where am I...?")
      |> specialeffect2(:venomdust)
      |> next()
      |> mes("- Pzzzz -")
      |> specialeffect(:cloaking)
      |> next()
      |> mes("^660000Surprisingly, your arm passed through her body.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...Where the hell am I?")
    |> close()
  end
end
