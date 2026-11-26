defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Prince3 do
  @moduledoc """
  The third prince’s body helps expose the Geoborg family curse.

  ## Behavior

  - The player discusses the deaths and can test for poison with a Green Potion and Yellow Gemstone.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
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
        map: "prt_church",
        x: 24,
        y: 111,
        dir: 5,
        sprite: 887,
        name: "",
        scope: :shared,
        unique_name: "#prince3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :prt_curse, 0) do
      21 -> examine_prince(ctx)
      22 -> continue_upstairs(ctx)
      stage when stage in [32, 41, 51] -> test_poison(ctx)
      stage when stage in [33, 42, 52] -> cleared_marks(ctx)
      _ -> describe_body(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp examine_prince(ctx) do
    ctx
    |> mes("^3355FFYou and Father Bamph")
    |> mes("hurriedly inspect the third")
    |> mes("prince's body and find that the")
    |> mes("scale marks on his skin are")
    |> mes("a little darker than the marks")
    |> mes("on the second prince's skin.^000000")
    |> next()
    |> mes("[Father Bamph]")
    |> mes("This is very suspicious...")
    |> mes("The deaths of the second and")
    |> mes("third princes might have been")
    |> mes("caused by murder, rather than")
    |> mes("the curse. However, what could")
    |> mes("possibly be used to kill them?")
    |> next()
    |> discuss_cause()
    |> mes("[Father Bamph]")
    |> mes("Poison...?")
    |> mes("Oh dear! No one in the")
    |> mes("Prontera Church would know")
    |> mes("the first thing about that. But")
    |> mes("maybe poison was used.")
    |> mes("How can we find out for sure?")
    |> next()
    |> mes("[Father Biscuss]")
    |> mes("I say, you go straight to")
    |> mes("the experts. Someone in the")
    |> mes("^FF0000Assassin Guild in Morocc^000000")
    |> mes("ought to know. I hear they")
    |> mes("can make poison that can kill")
    |> mes("a man with just one drop!")
    |> next()
    |> mes("[Father Bamph]")
    |> mes("Ah, that's a good idea!")
    |> mes("Hmm, but first, let's go")
    |> mes("continue this conversation")
    |> mes("outside, shall we? I'd prefer")
    |> mes("not to disturb these bodies...")
    |> set_char_var(:prt_curse, 22)
    |> close()
  end

  defp continue_upstairs(ctx) do
    ctx
    |> mes("[Father Bamph]")
    |> mes("Let's go upstairs where we")
    |> mes("can continue this conversation.")
    |> mes("Ah, you might want to ask")
    |> mes("Father Biscuss to lead you.")
    |> close()
  end

  defp test_poison(ctx) do
    if count_item(ctx, 506) > 0 and count_item(ctx, 715) > 0 do
      ctx =
        ctx
        |> mes("^3355FFYou open a bottle of")
        |> mes("Green Potion and insert a")
        |> mes("Yellow Gemstone. The gem")
        |> mes("quickly dissolves, conveniently")
        |> mes("forming a solution to test for the presense of poison. You pour")
        |> mes("it on the prince's scale marks.^000000")
        |> next()
        |> specialeffect(:poisonattack)
        |> specialeffect(:poisonhit)
        |> specialeffect(:bubble)
        |> mes("^3355FF*Pssssssssh*^000000")
        |> next()
        |> mes("^3355FFThe solution bubbles")
        |> mes("once it touches the skin,")
        |> mes("and the serpent scale marks")
        |> mes("on the prince's body slowly")
        |> mes("fade until they disappear.^000000")
        |> delitem(506, 1)
        |> delitem(715, 1)

      next_stage =
        case get_char_var(ctx, :prt_curse, 0) do
          32 -> 33
          41 -> 42
          _ -> 52
        end

      ctx
      |> set_char_var(:prt_curse, next_stage)
      |> close()
    else
      ctx
      |> mes("^3355FFYou'll need to have")
      |> mes("a Green Potion and")
      |> mes("a Yellow Gemstone in")
      |> mes("order to test and confirm")
      |> mes("whether poison killed the")
      |> mes("second and third princes.^000000")
      |> close()
    end
  end

  defp cleared_marks(ctx) do
    ctx
    |> mes("^3355FFThe serpent scale marks")
    |> mes("on this prince's body have")
    |> mes("vanished after you applied")
    |> mes("the Green Potion and Yellow")
    |> mes("Gemstone solution to the skin.^000000")
    |> close()
  end

  defp describe_body(ctx) do
    ctx
    |> mes("^3355FFIt's the body of a male")
    |> mes("dressed in luxurious robes.")
    |> mes("Although deceased, the color")
    |> mes("of life has not yet left the body. ")
    |> close()
  end

  defp discuss_cause(ctx) do
    {ctx, choice} = select(ctx, ["A weapon!", "Poison!"])

    if choice == 1 do
      ctx
      |> mes("[Father Bamph]")
      |> mes("Hmm... But none of the")
      |> mes("bodies had any wounds")
      |> mes("or scarring. If that were the")
      |> mes("case, I'm sure the king would")
      |> mes("have declared war on someone.")
      |> mes("It couldn't have been a weapon.")
      |> next()
      |> discuss_cause()
    else
      ctx
    end
  end
end
