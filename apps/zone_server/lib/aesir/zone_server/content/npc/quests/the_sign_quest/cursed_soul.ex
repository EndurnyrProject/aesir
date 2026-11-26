defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.CursedSoul do
  @moduledoc """
  A cursed spirit guards a spell book for the Sign quest.

  ## Behavior

  - Offers book choices and a spell challenge that can award the witch's book.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "niflheim",
        x: 348,
        y: 257,
        dir: 1,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#Cursed Soul",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
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
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if get_char_var(ctx, :sign_q, 0) == 83 or get_char_var(ctx, :sign_q, 0) == 90 do
      if get_char_var(ctx, :sign_sq, 0) == 0 do
        {ctx, choice} =
          ctx
          |> killmonster("niflheim", "#Cursed Soul::OnMyMobDead")
          |> mes("[Ashe Bruce]")
          |> mes("Leave now, or I will")
          |> mes("remove you by force....")
          |> next()
          |> mes("[Ashe Bruce]")
          |> mes("....And...")
          |> mes("....Whatever you do...")
          |> mes("....Do NOT touch my books...")
          |> next()
          |> select([
            "Pick up the 1st book.",
            "Pick up the 2nd book.",
            "Pick up the 3rd book.",
            "Leave immediately."
          ])

        case choice do
          1 ->
            ctx
            |> summon_mob(mob_id: 1478, map: "niflheim", at: {349, 259}, name: "Rideword")
            |> mes("[Ashe Bruce]")
            |> mes("...!...")
            |> mes("How dare you touch my books")
            |> mes("when I specifically said")
            |> mes("'Don't touch my books!'")
            |> next()
            |> mes("[Ashe Bruce]")
            |> mes("....!...Grrrrr!")
            |> mes("I shall tear you apart...!")
            |> mes("Be bound by an eternal curse...!")
            |> close()

          2 ->
            ctx
            |> mes("[Ashe Bruce]")
            |> mes("...!...")
            |> mes("You dare touch my books?!")
            |> mes("Right after I said not")
            |> mes("to touch them...?!")
            |> mes("Foolish mortal!")
            |> mes("...BEGONE!")
            |> close()

          3 ->
            cast_spell(ctx)

          4 ->
            ctx
            |> mes("[Ashe Bruce]")
            |> mes("Well then.")
            |> mes("Try not to trip on")
            |> mes("your feet in your")
            |> mes("rush to leave.")
            |> close()

          _ ->
            ctx
        end
      else
        ctx
      end
    else
      ctx
    end
  end

  defp cast_spell(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Ashe Bruce]")
      |> mes("Muhahahaha....")
      |> mes("Stubborn mortal~!")
      |> mes("Fine! I will give you")
      |> mes("a fighting chance and let")
      |> mes("you cast a spell.")
      |> next()
      |> select(["Clover", "Klaatu", "Kleitos"])

    ctx =
      if answer == 2 do
        set_local(ctx, :spell, get_local(ctx, :spell, 0) + 1)
      else
        ctx
      end

    {ctx, response} = select(ctx, ["Verit", "Veritas", "Verata"])

    ctx =
      if response == 3 do
        set_local(ctx, :spell, get_local(ctx, :spell, 0) + 1)
      else
        ctx
      end

    {ctx, final_choice} =
      select(ctx, ["Necktie", "Necklace", "Nero", "^FFFFFFNictu^000000"])

    ctx =
      if final_choice == 4 do
        set_local(ctx, :spell, get_local(ctx, :spell, 0) + 1)
      else
        ctx
      end

    if get_local(ctx, :spell, 0) == 3 do
      if Enum.random(1..5) == 5 do
        ctx
        |> mes("[Ashe Bruce]")
        |> mes("That was the right")
        |> mes("spell! But nothing")
        |> mes("happened. Madness!")
        |> close()
      else
        ctx =
          ctx
          |> mes("[Ashe Bruce]")
          |> mes("That spell...")
          |> mes("You removed my curse?")
          |> mes("I don't believe it. I'm free!")
          |> next()
          |> mes("[Ashe Bruce]")
          |> mes("But do not underestimate")
          |> mes("my awesome powers! In fact,")
          |> mes("I command you to take this")
          |> mes("book and give it to that")
          |> mes("weak, pathetic witch!")

        ctx =
          if get_char_var(ctx, :sign_q, 0) == 83 do
            if get_char_var(ctx, :sign_sq, 0) == 0 do
              ctx |> set_char_var(:sign_sq, 1) |> give_item(7304, 1)
            else
              ctx
            end
          else
            if get_char_var(ctx, :sign_q, 0) == 90 do
              ctx |> set_char_var(:sign_q, 91) |> give_item(7304, 1)
            else
              ctx
            end
          end

        close(ctx)
      end
    else
      ctx
      |> summon_mob(
        mob_id: 1462,
        map: "niflheim",
        at: {345, 259},
        name: "Orc Skeleton",
        event: "#Cursed Soul::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1462,
        map: "niflheim",
        at: {347, 261},
        name: "Orc Skeleton",
        event: "#Cursed Soul::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1462,
        map: "niflheim",
        at: {344, 253},
        name: "Orc Skeleton",
        event: "#Cursed Soul::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1462,
        map: "niflheim",
        at: {346, 251},
        name: "Orc Skeleton",
        event: "#Cursed Soul::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1462,
        map: "niflheim",
        at: {349, 249},
        name: "Orc Skeleton",
        event: "#Cursed Soul::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1462,
        map: "niflheim",
        at: {350, 260},
        name: "Orc Skeleton",
        event: "#Cursed Soul::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1462,
        map: "niflheim",
        at: {353, 256},
        name: "Orc Skeleton",
        event: "#Cursed Soul::OnMyMobDead"
      )
      |> mes("[Ashe Bruce]")
      |> mes("Muhahahahahaha!")
      |> mes("That's not the right spell!")
      |> mes("Now, death awaits you!")
      |> close()
    end
  end

  def ev_onmymobdead(ctx) do
    ctx
  end
end
