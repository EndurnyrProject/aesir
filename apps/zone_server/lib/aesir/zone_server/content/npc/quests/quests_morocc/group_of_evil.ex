defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.GroupOfEvil do
  @moduledoc """
  The group of evil starts the Satan Morocc encounter.

  ## Behavior

  - Eligible adventurers can trigger the encounter when the gap is ready.

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
        map: "moc_fild21",
        x: 178,
        y: 239,
        dir: 0,
        sprite: 844,
        name: "Group of Evil",
        scope: :shared,
        unique_name: "Group of Evil#edq",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if (get_char_var(ctx, :rebirth_moc_edq, 0) == 4 or get_char_var(ctx, :rebirth_moc_edq, 0) == 7) and
         get_server_temp_var(ctx, "re_moc", 0) == 1 do
      ctx =
        ctx
        |> mes(
          "Awed by the time-space gap where darkness is given life, you instinctively step back."
        )
        |> next()
        |> mes(
          "You can feel the power of the darkness rise from the gap where light and darkness are mingled."
        )
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Wah...!")
        |> close2()

      if get_server_temp_var(ctx, "re_moc", 0) == 1 do
        ctx |> set_server_temp_var("re_moc", 2) |> donpcevent("Satan Summon#edq::OnEnable")
      else
        ctx
      end
    else
      ctx
      |> mes(
        "Awed by the time-space gap where darkness is given life, you instinctively step back."
      )
      |> next()
      |> mes(
        "You can feel the power of the darkness rise from the gap where light and darkness are mingled."
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("Group of Evil#edq") |> set_server_temp_var("re_moc_time$", "")
  end
end
