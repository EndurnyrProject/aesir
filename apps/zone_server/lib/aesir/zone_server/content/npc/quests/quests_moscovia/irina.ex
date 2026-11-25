defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Irina do
  @moduledoc """
  Irina offers to make a Shafka hat.

  ## Behavior

  - She explains the hat and exchanges the required materials for one.

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
        map: "moscovia",
        x: 211,
        y: 93,
        dir: 3,
        sprite: 958,
        name: "Irina",
        scope: :shared,
        unique_name: "Irina#edq"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if not Rathena.truthy?(checkweight(ctx, [{1201, 1}])) do
      ctx
      |> mes("Wait a moment!!")
      |> mes("You have too many items.")
      |> mes("You can't receive this.")
      |> mes("Lighten your weight and")
      |> mes("try again.")
      |> close()
    else
      greet(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Irina]")
      |> mes("Hello, foreign traveler!")
      |> mes("Have you had good day")
      |> mes("in Moscovia?")
      |> next()
      |> mes("[Irina]")
      |> mes("A special souvenir for visiting Moscovia...?")
      |> next()
      |> mes("[Irina]")
      |> mes("For you, let's make a Shafka hat.")
      |> mes("The Shafka has practicality and")
      |> mes("it's spruce! Do you want one?")
      |> next()
      |> select(["Learn about the Shafka.", "Make a Shafka hat."])

    if choice == 1 do
      explain_hat(ctx)
    else
      make_hat(ctx)
    end
  end

  defp explain_hat(ctx) do
    ctx
    |> mes("[Irina]")
    |> mes("When I look at you, you seem to")
    |> mes("want to put on something of a thick")
    |> mes("fur hat on your head, out in this")
    |> mes("temperature. A Shafka!")
    |> next()
    |> mes("[Irina]")
    |> mes("If you've come here for the first")
    |> mes("time, you might not know... that")
    |> mes("winter here is famous for being so")
    |> mes("long and cold in Moscovia.")
    |> next()
    |> mes("[Irina]")
    |> mes("A Shafka hat is especially")
    |> mes("necessary to live here during the")
    |> mes("cold seasons. Without this hat, you")
    |> mes("may not endure a winter!")
    |> next()
    |> mes("[Irina]")
    |> mes("Now, the long, long winter has")
    |> mes("ended and the sun is shining... But")
    |> mes("someday the winter will come again.")
    |> mes("So, for preparation, you should")
    |> mes("keep a Shafka hat handy.")
    |> next()
    |> mes("[Irina]")
    |> mes("Don't worry about keeping warm if")
    |> mes("you're wearing a Shafka hat. Even")
    |> mes("during the coldest weather... You")
    |> mes("can roll around in the snow and the")
    |> mes("Shafka still keeps you warm!")
    |> close()
  end

  defp make_hat(ctx) do
    ctx =
      ctx
      |> mes("[Irina]")
      |> mes("Do you want to make a Shafka hat?")
      |> mes("Heheh. Good idea!")
      |> mes("That's a good task.")
      |> mes("You will be grateful forever.")
      |> next()
      |> mes("[Irina]")
      |> mes("If you bring the materials,")
      |> mes("we can make one immediately!")
      |> mes(
        "The materials are: ^0000FFNine Tails 20, Yarn 10, Soft Silk 10, Sea-otter Fur 20, Spool 1^000000."
      )

    ctx = if isbegin_quest(ctx, 18121) == 0, do: setquest(ctx, 18121), else: ctx
    ctx = next(ctx)

    if count_item(ctx, 1022) > 19 and count_item(ctx, 7038) > 9 and
         count_item(ctx, 7166) > 9 and count_item(ctx, 7065) > 19 and
         Rathena.truthy?(count_item(ctx, 7217)) do
      complete_hat(ctx)
    else
      missing_materials(ctx)
    end
  end

  defp complete_hat(ctx) do
    ctx
    |> mes("[Irina]")
    |> mes("You did well.")
    |> mes("Give me the materials. I will make the Shafka.")
    |> next()
    |> delitem(1022, 20)
    |> delitem(7038, 10)
    |> delitem(7166, 10)
    |> delitem(7065, 20)
    |> delitem(7217, 1)
    |> give_item(5243, 1)
    |> completequest(18121)
    |> mes("[Irina]")
    |> mes("Good, I made it. So, how about it?")
    |> mes("Do you like it?")
    |> next()
    |> mes("[Irina]")
    |> mes("If you need a Shafka hat,")
    |> mes("come to me whenever,")
    |> mes("with the materials.")
    |> mes("I will make it.")
    |> next()
    |> mes("[Irina]")
    |> mes("Okay?")
    |> mes("Okay, so... Bye-bye!~")
    |> close()
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Irina]")
    |> mes("Ah... You lack some materials. We")
    |> mes("can't make the Shafka hat with just")
    |> mes("these materials.")
    |> next()
    |> mes("[Irina]")
    |> mes("If you bring the right materials, I")
    |> mes("will make a Shafka immediately.")
    |> next()
    |> mes("[Irina]")
    |> mes(
      "The materials are: ^0000FFNine Tails 20, Yarn 10, Soft Silk 10, Sea-otter Fur 20, Spool 1^000000."
    )
    |> close()
  end
end
