defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.StoneFurnace do
  @moduledoc """
  A stone furnace challenges adventurers to retrieve cookies.

  ## Behavior

  - Burns unsuccessful adventurers and summons a guard after success.

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
        map: "mosk_que",
        x: 45,
        y: 131,
        dir: 0,
        sprite: 111,
        name: "Stone Furnace",
        scope: :shared,
        unique_name: "Stone Furnace#rus28"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnMyMobDead", ctx) do
    ev_onmymobdead(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer300000", ctx) do
    ev_ontimer300000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_main, 0) != 8 or
          get_char_var(ctx, :rhea_rus_quiz, 0) != 1 ->
        emotion(ctx, :question, playerattached(ctx))

      getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...Hmm, did I forget to wear something...?")
        |> close()

      true ->
        take_cookies(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp take_cookies(ctx) do
    ctx =
      ctx
      |> mes("- You can see the -")
      |> mes("- well baked cookies. -")
      |> mes("- Be careful and -")
      |> mes("- don't get burned -")
      |> next()

    if Enum.random(1..3) == 2 do
      ctx
      |> mes("- You quickly stretch out -")
      |> mes("- your hand and pick up -")
      |> mes("- the well baked cookies! -")
      |> next()
      |> mes("- ^0000ffYou got 100^000000 -")
      |> mes("- ^0000ffWell Baked Cookies!!^000000 -")
      |> next()
      |> summon_guard()
      |> close()
    else
      ctx =
        ctx
        |> mes("- You quickly stretch out -")
        |> mes("- your hand and pick up -")
        |> mes("- the well baked cookies! -")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Oops, it's hot, hot!!!")
        |> specialeffect2(:firehit)

      ctx
      |> emotion(:huk, playerattached(ctx))
      |> percent_heal(hp: -5, sp: 0)
      |> close()
    end
  end

  defp summon_guard(ctx) do
    ctx =
      ctx
      |> mes("[Marozka's Guard]")
      |> mes("How did this rat get inside the cave?!")
      |> announce("Marozka's Guard : Invader! Search the whole cave!!", 1, 8_900_331)
      |> set_char_var(:rhea_rus_quiz, 2)

    if not Rathena.truthy?(get_server_temp_var(ctx, "rus_req01", 0)) do
      ctx
      |> initnpctimer()
      |> summon_mob(
        mob_id: 1889,
        map: "mosk_que",
        at: {49, 156},
        name: "Marozka's Guard",
        event: "Stone Furnace#rus28::OnMyMobDead"
      )
      |> set_server_temp_var("rus_req01", 1)
    else
      ctx
    end
  end

  def ev_onmymobdead(ctx) do
    ctx
    |> stopnpctimer()
    |> set_server_temp_var("rus_req01", 0)
    |> announce(
      "Mazroka : You are truly brave. When you get the cookies and apples, come to see me.",
      1,
      8_900_331
    )
  end

  def ev_ontimer300000(ctx) do
    ctx
    |> killmonster("mosk_que", "Stone Furnace#rus28::OnMyMobDead")
    |> stopnpctimer()
    |> ev_oninit()
  end

  def ev_oninit(ctx) do
    set_server_temp_var(ctx, "rus_req01", 0)
  end
end
