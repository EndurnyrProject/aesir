defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.Bain do
  @moduledoc """
  Bain collects supplies for the alchemist brothers' talking doll experiment.

  ## Behavior

  - Requests materials and zeny and offers rewards for the experiment.
  - Advances the alchemist quest when the supplies are delivered.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - kobra_k88
    - Darkchild
    - Lupus
    - Samuray22
    - akrus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 103,
        y: 157,
        dir: 3,
        sprite: 98,
        name: "Bain",
        scope: :shared,
        unique_name: "Bain#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> overweight(ctx)
      has_materials?(ctx) -> experiment(ctx)
      true -> quest_dialogue(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overweight(ctx) do
    ctx
    |> mes("- Wait a minute !! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please try again -")
    |> mes("- after you lose some weight. -")
    |> close()
  end

  defp has_materials?(ctx) do
    count_item(ctx, 974) > 0 and count_item(ctx, 612) > 4 and count_item(ctx, 1003) > 4 and
      count_item(ctx, 7068) > 4 and count_item(ctx, 7043) > 4 and count_item(ctx, 757) > 2 and
      count_item(ctx, 756) > 2 and zeny(ctx) >= 2000
  end

  defp experiment(ctx) do
    ctx =
      if get_char_var(ctx, :ALCH_Q, 0) == 23 do
        set_char_var(ctx, :ALCH_Q, 24)
      else
        ctx
      end

    ctx =
      ctx
      |> set_local(:kyulkwa, Enum.random(1..10))
      |> mes("[Bain]")
      |> mes("Oh ho ho... These are the parts that I needed. Thank you so much.")
      |> next()
      |> mes("[Bain]")
      |> mes("Okay, let's try this out! Hold on for just a second!")
      |> next()
      |> mes("^3355FF*Vrrrmmmmm*^000000")
      |> next()
      |> mes("^3355FF*Pakakkakakakkakaakapakakkakak*^000000")
      |> next()
      |> mes("^3355FF*Shakakakakkakakakakkakakakakka!*^000000")
      |> next()

    case get_local(ctx, :kyulkwa, 0) do
      roll when roll < 4 or roll > 8 -> reward(ctx, [1002, 5, 1])
      roll when roll in [5, 6, 8] -> reward(ctx, [723, 5, 1])
      7 -> reward(ctx, [969, 2, 0])
      _ -> quest_dialogue(ctx)
    end
  end

  defp quest_dialogue(ctx) do
    case get_char_var(ctx, :bros_q, 0) do
      1 -> remind_materials(ctx)
      0 -> offer_quest(ctx)
      _ -> reward(ctx, [])
    end
  end

  defp remind_materials(ctx) do
    ctx
    |> mes("[Bain]")
    |> mes("In case you")
    |> mes("forgot, these are the")
    |> mes("required materials.")
    |> mes("Write it down if you need to.")
    |> next()
    |> mes("[Bain]")
    |> mes("^FF00001 Mixture^000000, ^FF00005 Mini-Furnace^000000,")
    |> mes("^FF00005 Burnt Tree^000000 , ^FF00005 Coal^000000,")
    |> mes("^FF00005 Fine Sand^000000, ^FF00003 Rough Elunium^000000,")
    |> mes("^FF00003 Rough Oridecon^000000^000000.")
    |> next()
    |> mes("[Bain]")
    |> mes("In addition to this, you ")
    |> mes("will need 2,000 zeny.")
    |> mes("Good Luck...")
    |> close()
  end

  defp offer_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bain]")
      |> mes(
        "We are going to invent a doll that can can talk and communicate! Well, at least, I'm trying to."
      )
      |> next()
      |> mes("[Bain]")
      |> mes(
        "I got the idea from a historical legend. I figure that if it's been done before, this project is definitely possible."
      )
      |> next()
      |> mes("[Bain]")
      |> mes("But right now, I lack the supplies")
      |> mes("and parts that I need to attempt")
      |> mes("this feat. I don't know how")
      |> mes("they gathered all the necessary materials....")
      |> next()
      |> mes("[Bain]")
      |> mes("Money can only buy some of what I")
      |> mes("need. There are also those items")
      |> mes("that need to be taken from")
      |> mes("monsters that are much too")
      |> mes("powerful. How will I continue my research?")
      |> next()
      |> select(["I'll get them for you.", "Good luck."])

    if choice == 1 do
      ctx
      |> set_char_var(:bros_q, 1)
      |> mes("[Bain]")
      |> mes("Really? Such benevolence is rare")
      |> mes("in this day and age. We would be")
      |> mes("grateful for your assistance.")
      |> mes("Here are the items that we will be")
      |> mes("needing.")
      |> next()
      |> mes("[Bain]")
      |> mes("^FF00001 Mixture^000000, ^FF00005 Mini-Furnace^000000,")
      |> mes("^FF00005 Burnt Tree^000000 , ^FF00005 Coal^000000,")
      |> mes("^FF00005 Fine Sand^000000, ^FF00003 Rough Elunium^000000,")
      |> mes("^FF00003 Rough Oridecon^000000^000000.")
      |> next()
      |> mes("[Bain]")
      |> mes("We will also need 2,000 Zeny.")
      |> mes("The money will help pay for the")
      |> mes("minor expenses involved in undertaking this endeavor.")
      |> mes("Godspeed.")
      |> close()
    else
      ctx
      |> mes("[Bain]")
      |> mes("I wish I could be")
      |> mes("a strong adventurer")
      |> mes("like you.")
      |> close()
    end
  end

  defp reward(ctx, args) do
    ctx =
      ctx
      |> delitem(974, 1)
      |> delitem(612, 5)
      |> delitem(1003, 5)
      |> delitem(7068, 5)
      |> delitem(7043, 5)
      |> delitem(757, 3)
      |> delitem(756, 3)
      |> pay_zeny(2000)
      |> give_item(Enum.at(args, 0, 0), Enum.at(args, 1, 0))
      |> mes("[Bain]")
      |> mes("AHHH, it is a success!")
      |> mes("I don't know if we can do anything else,")

    ctx =
      if Enum.at(args, 2, 0) == 1 do
        mes(ctx, Rathena.concat("but this time we have created ", Enum.at(args, 1, 0)))
      else
        mes(ctx, "but this time we have created")
      end

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("^FF0000", Rathena.getitemname(Enum.at(args, 0, 0))),
        "^000000 !"
      )
    )
    |> next()
    |> mes("[Bain]")
    |> mes("Now that we know that it works")
    |> mes("I don't have any need for this.")
    |> mes("Why don't you take it? Oh,")
    |> mes("and if you find any more parts,")
    |> mes("bring them to me again. Heheheh.")
    |> next()
    |> mes("[Bain]")
    |> mes("Thank you for helping me out.")
    |> mes("You have my eternal gratitude.")
    |> mes("I wish you luck in your journeys!")
    |> close()
  end
end
