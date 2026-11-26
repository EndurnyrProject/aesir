defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Entrancecheck9892 do
  @moduledoc """
  Controls the entrance to the hideout during the investigation.

  ## Behavior

  - Starts the encounter or reveals its occupants according to quest progress.
  - Returns unexpected visitors to the field and resets the encounter flags.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "z_agit",
        x: 98,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "EntranceCheck",
        scope: :shared,
        unique_name: "EntranceCheck#2",
        trigger: {10, 10}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    progress = get_char_var(ctx, :zdan_edq, 0)

    cond do
      progress in [15, 16] and get_server_temp_var(ctx, "monster_zgang", 0) == 0 ->
        ctx |> set_server_temp_var("monster_zgang", 1) |> donpcevent("#zdan_broad::OnEnable")

      progress in [15, 16] and get_server_temp_var(ctx, "monster_zgang", 0) > 0 ->
        ctx

      progress == 17 ->
        ctx
        |> donpcevent("#ZGuard::OnDisable")
        |> hideoffnpc("Louis")
        |> hideoffnpc("Martha")
        |> hideoffnpc("Catfoii")

      true ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Where am I...?")
        |> mes("Something has gone")
        |> mes("terribly wrong, hasn't")
        |> mes("it? Let me go baaaack~! ")
        |> close2()
        |> set_server_temp_var("monster_zgang", 0)
        |> set_server_temp_var("door2", 0)
        |> warp("moc_fild17", 209, 235)
    end
  end
end
