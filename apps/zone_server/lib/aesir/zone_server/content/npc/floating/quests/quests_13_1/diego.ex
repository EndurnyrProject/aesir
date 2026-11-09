defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.Diego do
  @moduledoc """
  Diego, the expedition member left holding up a broken barracks post, who trades the
  repair story for 20 Ordinary Branches and 20 Strong Vines.

  ## Behavior

  - Shrugs off a player who is not on his errand (steps outside 5..9).
  - At step 5 offers the repair job through a Help him / Don't help menu; accepting walks
    through the story and asks for 20 Ordinary Branches and 20 Strong Vines, setting
    `ep13_newbs` to 6 and starting quest 11087.
  - At step 6 takes the materials, consumes 20 of each, advances `ep13_newbs` to 7 and quest
    11087 to 11088, and keeps asking while they are short.
  - At steps 7 and 8 repeats the instructions for attaching and tying the branches.
  - At step 9, inventory space permitting, hands over 5 Chocolate Pies, completes quest
    11090, sets `ep13_newbs` to 10 and warps the player into the camp building.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 266,
        y: 263,
        dir: 4,
        sprite: 931,
        name: "Diego",
        scope: :renewal,
        unique_name: "Diego#ep13bs"
      },
      %{
        map: "mid_camp",
        x: 264,
        y: 263,
        dir: 4,
        sprite: 931,
        name: "Diego",
        scope: :pre_renewal,
        unique_name: "Diego#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @strong_vine 6041
  @ordinary_branch 6042
  @materials_needed 20

  @chocolate_pie 12322
  @pies_rewarded 5

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      step when step < 5 -> busy(ctx)
      5 -> ask_for_help(ctx)
      6 -> accept_materials(ctx)
      7 -> attach_branches(ctx)
      8 -> second_post(ctx)
      9 -> thanks(ctx)
      _step -> busy(ctx)
    end
  end

  defp busy(ctx) do
    ctx
    |> mes("[Diego]")
    |> mes("I'm busy right now!")
    |> emotion(:profusely_sweat)
    |> close()
  end

  defp ask_for_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Diego]")
      |> mes("Wow, this is tent is big!")
      |> mes("Hey, you there, adventurer. Please help me.")
      |> emotion(:cry)
      |> next()
      |> select(["Help him.", "Don't help."])

    case choice do
      1 -> explain_repairs(ctx)
      2 -> refuse(ctx)
      _ -> ctx
    end
  end

  defp explain_repairs(ctx) do
    ctx =
      ctx
      |> mes("[Diego]")
      |> mes("Thanks.")
      |> emotion(:thanks)
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What do you need?")
      |> next()
      |> mes("[Diego]")
      |> mes("Ah...")
      |> mes("When I passed by here...")
      |> mes("I kicked the post by mistake")
      |> mes("and now it's broken.")
      |> next()
      |> mes("[Diego]")
      |> mes("I need to ask others for help")
      |> mes("while I hold this post up.")
      |> next()
      |> mes("[Diego]")
      |> mes("Well, let me see...")
      |> mes("I'm really lucky to see you,")

    ctx =
      ctx
      |> mes("passing by here, #{char_name(ctx, 0)}.")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hah!! How did you know my name?!")

    {ctx, _} =
      ctx
      |> emotion(:huk, playerattached(ctx))
      |> next()
      |> mes("[Diego]")
      |> mes("It's on your nameplate.")
      |> emotion(:think)
      |> next()
      |> select(["So how can I help you."])

    ctx
    |> mes("[Diego]")
    |> mes("While I hold this post up,")
    |> mes("please get materials to fix it.")
    |> next()
    |> mes("[Diego]")
    |> mes("I need the bar to sustain this")
    |> mes("post and a rope to tie it.")
    |> next()
    |> mes("[Diego]")
    |> mes("You can find many trees")
    |> mes("west of the camp for branches")
    |> mes("that we can use as a post.")
    |> next()
    |> mes("[Diego]")
    |> mes("And you can find the weird")
    |> mes("plant called ^0000FFNepenthes^000000")
    |> mes("at the field east of the camp it's vines are very strong.")
    |> next()
    |> mes("[Diego]")
    |> mes("I think we should be")
    |> mes("able to fix this with")
    |> mes("^0000FF20 Ordinary Branches and 20 Strong Vine^000000.")
    |> mes("Please bring them to me!!!")
    |> set_char_var(:ep13_newbs, 6)
    |> setquest(11087)
    |> close()
  end

  defp refuse(ctx) do
    ctx
    |> mes("[Diego]")
    |> mes("...")
    |> mes("You're too harsh.")
    |> mes("Sob...")
    |> emotion(:cry)
    |> close()
  end

  defp accept_materials(ctx) do
    if count_item(ctx, @strong_vine) > 19 and count_item(ctx, @ordinary_branch) > 19 do
      ctx
      |> mes("[Diego]")
      |> mes("Oh!!")
      |> mes("You finally brought")
      |> mes("the materials!")
      |> mes("I'm so grateful!!")
      |> emotion(:cry)
      |> next()
      |> mes("[Diego]")
      |> mes("Ok, so while I hold this post,")
      |> mes("please attach the branches")
      |> mes("and tie it up with the vines.")
      |> delitem(@strong_vine, @materials_needed)
      |> delitem(@ordinary_branch, @materials_needed)
      |> set_char_var(:ep13_newbs, 7)
      |> changequest(11087, 11088)
      |> close()
    else
      bring_materials(ctx)
    end
  end

  defp bring_materials(ctx) do
    ctx
    |> mes("[Diego]")
    |> mes("I think we should be")
    |> mes("able to fix this with")
    |> mes("^0000FF20 Ordinary Branches and 20 Strong Vine^000000.")
    |> mes("Please bring them to me!!!")
    |> close()
  end

  defp attach_branches(ctx) do
    ctx
    |> mes("[Diego]")
    |> mes("Ok, so while I hold this post,")
    |> mes("please attach the branches")
    |> mes("and tie it up with the vines.")
    |> close()
  end

  defp second_post(ctx) do
    ctx
    |> mes("[Diego]")
    |> mes("Please do the same for the other one.")
    |> close()
  end

  defp thanks(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      overburdened(ctx)
    else
      reward(ctx)
    end
  end

  defp overburdened(ctx) do
    ctx
    |> mes("- Wait a minute !! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please try again -")
    |> mes("- after you lose some weight. -")
    |> close()
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Diego]")
      |> mes("Thanks to your help,")
      |> mes("I can protect the barracks.")
      |> mes("When I was in trouble,")
      |> mes("you came along.")
      |> mes("It's got to be fate.")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("No, I just...")
      |> mes("I was assigned to stay")
      |> mes("in these barracks.")

    ctx
    |> emotion(:profusely_sweat, playerattached(ctx))
    |> next()
    |> mes("[Diego]")
    |> mes("Oh!!!")
    |> mes("Then it this really is fate!!!")
    |> mes("And this is the special")
    |> mes("product of this camp,")
    |> mes("^0000FFChocolate Pie^000000.")
    |> next()
    |> mes("[Diego]")
    |> mes("Please come in and")
    |> mes("take some rest for the")
    |> mes("expedition tomorrow!!")
    |> set_char_var(:ep13_newbs, 10)
    |> give_item(@chocolate_pie, @pies_rewarded)
    |> completequest(11090)
    |> close()
    |> warp("mid_campin", 291, 128)
  end
end
