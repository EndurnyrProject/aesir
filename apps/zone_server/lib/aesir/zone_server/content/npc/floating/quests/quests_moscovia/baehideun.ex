defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMoscovia.Baehideun do
  @moduledoc """
  A ship encounter summons sea monsters and ends when they are defeated or time runs out.

  ## Behavior

  - Enables the encounter, manages its timer and updates quest progress after the monsters die.

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
      %{name: "Baehideun", scope: :shared, unique_name: "Baehideun#main"},
      %{
        map: "mosk_ship",
        x: 2,
        y: 2,
        dir: 4,
        sprite: -1,
        name: "Baehideun1",
        scope: :shared,
        unique_name: "Baehideun1#ship"
      },
      %{
        map: "mosk_ship",
        x: 5,
        y: 5,
        dir: 4,
        sprite: -1,
        name: "Baehideun3",
        scope: :shared,
        unique_name: "Baehideun3#ship"
      },
      %{
        map: "mosk_ship",
        x: 15,
        y: 15,
        dir: 4,
        sprite: -1,
        name: "Baehideun4",
        scope: :shared,
        unique_name: "Baehideun4#ship"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer300000", ctx) do
    ev_ontimer300000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnMyMobDead", ctx) do
    ev_onmymobdead(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx)
  end

  def ev_onenable(ctx) do
    ctx = enablenpc(ctx)
    ctx = set_local(ctx, :c, Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 0), 9)))

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        ship_number = get_local(ctx, :c, 0)

        case ship_number do
          1 ->
            set_local(ctx, :m, [89, 112, 1551, 85, 110, 1579])

          2 ->
            set_local(ctx, :m, [89, 112, 1425, 80, 110, 1254, 83, 114, 1254, 85, 110, 1425])

          3 ->
            set_local(ctx, :m, [85, 111, 1451, 89, 112, 1543, 90, 106, 1543])

          4 ->
            set_local(ctx, :m, [85, 111, 1069, 89, 112, 1543, 90, 106, 1543])

          _ ->
            ctx
        end
      else
        ship_number = get_local(ctx, :c, 0)

        case ship_number do
          1 ->
            set_local(ctx, :m, [89, 112, 1425, 85, 110, 1425])

          2 ->
            set_local(ctx, :m, [89, 112, 1425, 80, 110, 1426, 83, 114, 1426, 85, 110, 1425])

          v when v in [3, 4] ->
            set_local(ctx, :m, [85, 111, 1451, 89, 112, 1543, 90, 106, 1543])

          _ ->
            ctx
        end
      end

    ctx |> set_local(:i, 0) |> summon_monsters() |> initnpctimer()
  end

  def ev_ontimer300000(ctx) do
    ctx
    |> killmonster("mosk_ship", Rathena.concat(strnpcinfo(ctx, 0), "::OnMyMobDead"))
    |> ev_ondisable()
  end

  def ev_ondisable(ctx) do
    ctx |> set_server_temp_var("mos1_edq", 0) |> stopnpctimer() |> disablenpc()
  end

  def ev_onmymobdead(ctx) do
    if not Rathena.truthy?(
         mobcount(ctx, "mosk_ship", Rathena.concat(strnpcinfo(ctx, 0), "::OnMyMobDead"))
       ) do
      ctx =
        ctx
        |> set_server_temp_var("mos1_edq", 0)
        |> mes("[Mr. Ibanoff]")
        |> mes("Now that all the monsters are gone,")
        |> mes("we can start sailing again")
        |> mes("normally.")

      ctx = set_local(ctx, :c, Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 0), 9)))

      ctx =
        case get_local(ctx, :c, 0) do
          3 -> set_char_var(ctx, :mos_whale_edq, 11)
          4 -> set_char_var(ctx, :mos_whale_edq, 26)
          _ -> ctx
        end

      ctx |> donpcevent(Rathena.concat(strnpcinfo(ctx, 0), "::OnDisable")) |> close()
    else
      ctx
    end
  end

  defp summon_monsters(ctx) do
    if get_local(ctx, :i, 0) < length(get_local(ctx, :m, [])) do
      ctx =
        summon_mob(ctx,
          mob_id: Enum.at(get_local(ctx, :m, []), get_local(ctx, :i, 0) + 2, 0),
          map: "mosk_ship",
          at:
            {Enum.at(get_local(ctx, :m, []), get_local(ctx, :i, 0), 0),
             Enum.at(get_local(ctx, :m, []), get_local(ctx, :i, 0) + 1, 0)},
          name: "Sea Monster",
          event: Rathena.concat(strnpcinfo(ctx, 0), "::OnMyMobDead")
        )

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 3) |> summon_monsters()
    else
      ctx
    end
  end
end
