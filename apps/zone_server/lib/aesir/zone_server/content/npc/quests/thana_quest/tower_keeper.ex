defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.TowerKeeper do
  @moduledoc """
  Gatei guards the entrance to Thanatos Tower.

  ## Behavior

  - Explains the tower and charges visitors an entrance fee.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_fild01",
        x: 140,
        y: 163,
        dir: 5,
        sprite: 852,
        name: "Tower Keeper",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ctx
    |> mes("[Tower Keeper]")
    |> mes("Excuse me, but you cannot")
    |> mes("enter. This place is under")
    |> mes("the Rekenber Corporation's")
    |> mes("administration, and this area")
    |> mes("is restricted to all those")
    |> mes("without authorization.")
    |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gatei]")
      |> mes("Greetings, adventurer.")
      |> mes("I am Gatei Knumm, keeper")
      |> mes("of this Thanatos Tower.")
      |> mes("How may I help you?")
      |> next()
      |> select(["Thanatos Tower?", "Entrance Fee?", "Enter the tower", "Cancel"])

    case choice do
      1 -> about_tower(ctx)
      2 -> about_fee(ctx)
      3 -> entry_menu(ctx)
      4 -> farewell(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp about_tower(ctx) do
    ctx
    |> mes("[Gatei]")
    |> mes("Yes, the tower in front")
    |> mes("of you was an ancient ruins")
    |> mes("that got its name from a word")
    |> mes("written on a stone plate found")
    |> mes("inside. Today, this place is")
    |> mes("a popular tourist attraction.")
    |> next()
    |> mes("[Gatei]")
    |> mes("This tower grew in popularity")
    |> mes("for adventurers when the")
    |> mes("Rekenber Corporation began")
    |> mes("tower reconstruction efforts.")
    |> mes("The 1st and 2nd floors are now")
    |> mes("repaired and free of monsters.")
    |> next()
    |> mes("[Gatei]")
    |> mes("However, reconstruction of")
    |> mes("the 3rd and higher floors is")
    |> mes("incomplete. Those levels are")
    |> mes("still infested with monsters, so we're contracting temp workers")
    |> mes("to exterminate all of them.")
    |> next()
    |> mes("[Gatei]")
    |> mes("If you're interested in")
    |> mes("temporary contract work,")
    |> mes("or would like to know about")
    |> mes("this place in detail, please")
    |> mes("ask one of the guides inside.")
    |> mes("Thank you and enjoy your visit~")
    |> close()
  end

  defp about_fee(ctx) do
    ctx
    |> mes("[Gatei]")
    |> mes("Everyone is welcome to")
    |> mes("enjoy Thanatos Tower.")
    |> mes("Only the 1st and 2nd floors")
    |> mes("are open to the public at")
    |> mes("this time. The entrance fee")
    |> mes("is 5,000 zeny per person.")
    |> next()
    |> mes("[Gatei]")
    |> mes("5,000 zeny may seem a little")
    |> mes("steep for a tourist attraction,")
    |> mes("but trust me, this tower provides a very unique experience. Also,")
    |> mes("our loyal customers and contract workers get a special discount~")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Gatei]")
    |> mes("Hmm? Very well.")
    |> mes("But if you wish to visit")
    |> mes("this Thanatos Tower, please")
    |> mes("do not hesitate to ask me.")
    |> mes("Thank you and have a nice day.")
    |> close()
  end

  defp entry_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gatei]")
      |> mes("Would you like to")
      |> mes("enter Thanatos Tower?")
      |> mes("The entry fee is ^FF00005,000 zeny^000000.")
      |> next()
      |> select(["Enter", "Maybe next time."])

    case choice do
      1 ->
        if get_char_var(ctx, :thana_tower, 0) > 0 do
          employee_entry(ctx)
        else
          visitor_entry(ctx)
        end

      2 ->
        ctx
        |> mes("[Gatei]")
        |> mes("Very well. Please come")
        |> mes("and visit us again here")
        |> mes("in Thanatos Tower.")
        |> close()

      _ ->
        ctx
    end
  end

  defp employee_entry(ctx) do
    ctx = mes(ctx, "[Gatei]")

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("Oh, ", char_name(ctx, 0)), "!"))
      |> mes("Welcome back! Since you've")
      |> mes("got a temporary Rekenber")
      |> mes("work contract, your entrance")
      |> mes("fee is only 3,000 zeny.")
      |> next()
      |> select(["Enter", "No, thanks."])

    case choice do
      1 ->
        employee_payment(ctx)

      2 ->
        ctx
        |> mes("[Gatei]")
        |> mes("You must be busy, then.")
        |> mes("Well, not to worry, we'll")
        |> mes("always be here. Farewell~")
        |> close()

      _ ->
        ctx
    end
  end

  defp employee_payment(ctx) do
    if zeny(ctx) > 2999 do
      ctx
      |> mes("[Gatei]")
      |> mes("Thank you, and")
      |> mes("please keep up the")
      |> mes("good work. Ah, and don't")
      |> mes("forget: safety first when")
      |> mes("you fight those monsters!")
      |> pay_zeny(3000)
      |> close2()
      |> warp("tha_scene01", 131, 220)
    else
      ctx
      |> mes("[Gatei]")
      |> mes("Oh, I'm sorry...")
      |> mes("But you don't seem to")
      |> mes("have enough zeny. Oh well,")
      |> mes("just come back again later~")
      |> close()
    end
  end

  defp visitor_entry(ctx) do
    if zeny(ctx) > 4999 do
      ctx
      |> mes("[Gatei]")
      |> mes("Ah, I've received your")
      |> mes("entrance fee. Thank you")
      |> mes("very much. Now, I hope")
      |> mes("you enjoy your visit")
      |> mes("to Thanatos Tower~")
      |> close2()
      |> pay_zeny(5000)
      |> warp("tha_scene01", 131, 220)
    else
      ctx
      |> mes("[Gatei]")
      |> mes("Well...")
      |> mes("Hm. I'm sorry, but you")
      |> mes("don't seem to have enough")
      |> mes("zeny for the entrance fee.")
      |> mes("Please come back later...")
      |> close()
    end
  end
end
