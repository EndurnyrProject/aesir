defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Seals.BrisingamenSeal.Librarian do
  @moduledoc """
  A royal librarian guards the Crusader personnel records.

  ## Behavior

  - Responds to seal progress and inquiries about Lowen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Librarian", scope: :shared, unique_name: "Librarian#2_"},
      %{
        map: "prt_cas",
        x: 373,
        y: 75,
        dir: 3,
        sprite: 105,
        name: "Librarian",
        unique_name: "Librarian#2",
        scope: :renewal
      },
      %{
        map: "prt_castle",
        x: 84,
        y: 51,
        dir: 5,
        sprite: 105,
        name: "Librarian",
        unique_name: "Librarian#2",
        scope: :pre_renewal
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        turn_away(ctx)

      get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        turn_away(ctx)

      get_char_var(ctx, :god_brising, 0) > 24 and get_char_var(ctx, :god_brising, 0) < 27 ->
        sleeping(ctx)

      get_char_var(ctx, :god_brising, 0) == 10 ->
        inquire(ctx)

      get_char_var(ctx, :god_brising, 0) > 10 and get_char_var(ctx, :god_brising, 0) < 13 ->
        dismiss(ctx)

      true ->
        restricted(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("What are you doing here?")
    |> mes("Don't touch anything!")
    |> close()
  end

  defp sleeping(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("Zzzzz...")
    |> mes("...Zzzzz...")
    |> mes("......Zzzzzz...")
    |> next()
    |> mes(
      "^3355FFThis librarian seems to be deeply asleep. It'd be smarter not to wake him if you want to check the Crusader Personnel Records.^000000"
    )
    |> close()
  end

  defp inquire(ctx) do
    {ctx, relationship} =
      ctx
      |> mes("[Librarian]")
      |> mes(
        "All confidential personnel records are kept here in the royal library. However, you need authorization"
      )
      |> mes("for full access.")
      |> next()
      |> mes("[Librarian]")
      |> mes("Did you say that you")
      |> mes("need to find a person?")
      |> mes("Please give me that")
      |> mes("person's name, as well")
      |> mes("as your relationship.")
      |> next()
      |> select(["Lowen, Sibling", "Lowen, Spouse", "Lowen, Enemy", "Lowen, a Friend"])

    case relationship do
      1 -> if sex(ctx) == 1, do: male_sibling(ctx), else: female_sibling(ctx)
      2 -> if sex(ctx) == 1, do: male_spouse(ctx), else: female_spouse(ctx)
      3 -> enemy(ctx)
      4 -> friend(ctx)
      _ -> ctx
    end
  end

  defp male_sibling(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("How dare you")
    |> mes("lie to the royal")
    |> mes("librarian!")
    |> next()
    |> mes("[Librarian]")
    |> mes("It says here")
    |> mes("in the records")
    |> mes("that Lowen did not")
    |> mes("have any male siblings!")
    |> next()
    |> mes("[Librarian]")
    |> mes("^333333(Crap...!")
    |> mes("I just disclosed")
    |> mes("^666666classified^000000 ^333333info!)^000000")
    |> next()
    |> mes("[Librarian]")
    |> mes("The Royal Library won't")
    |> mes("tolerate identity fraud!")
    |> mes("Please leave!")
    |> close()
  end

  defp female_sibling(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("You're related to Miss Lowen? How have you not received any news about her before?")
    |> next()
    |> mes("[Librarian]")
    |> mes("I see...")
    |> mes("Separated at birth,")
    |> mes("that's truly tragic.")
    |> mes("Okay, let me check.")
    |> next()
    |> mes("[Librarian]")
    |> mes(
      "I feel terrible telling you this, but it's too late to find Lowen Ellenen, according to the records."
    )
    |> next()
    |> mes("[Librarian]")
    |> mes(
      "During the monster subjugation mission in Geffen dungeon she reportedly disappeared and... was later pronounced dead."
    )
    |> next()
    |> mes("[Librarian]")
    |> mes("I'm sorry, but")
    |> mes("that's all I know.")
    |> mes("Thank you...")
    |> set_char_var(:god_brising, 11)
    |> close()
  end

  defp male_spouse(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("Spouse...?")
    |> mes(
      "Well, I guess you look like a husband. Heh, I've got a girlfriend myself. Well, at least I think so. Anyway..."
    )
    |> next()
    |> mes("[Librarian]")
    |> mes("Lowen Ellenen")
    |> mes("the Crusader, right?")
    |> mes("I'm so... sorry.")
    |> mes("You might want")
    |> mes("to have a seat.")
    |> next()
    |> mes("[Librarian]")
    |> mes("During the monster")
    |> mes("subjugation in Geffen")
    |> mes("Dungeon, she reportedly")
    |> mes("disappeared. And later,")
    |> mes("she was pronounced dead.")
    |> next()
    |> mes("[Librarian]")
    |> mes("That's all the")
    |> mes("information I have,")
    |> mes("sir. I'm truly sorry")
    |> mes("for your loss.")
    |> set_char_var(:god_brising, 11)
    |> close()
  end

  defp female_spouse(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("Hmmm...?")
    |> mes("Spouse?")
    |> mes("Or ^333333*Ahem*^000000")
    |> mes("cohabitational partners?")
    |> next()
    |> mes("^3355FFThe librarian")
    |> mes("now seems awfully")
    |> mes("distracted, as if")
    |> mes("he were lost in")
    |> mes("vivid daydream...^000000")
    |> close()
  end

  defp enemy(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I'm looking")
    |> mes("for Ellenen.")
    |> mes("Lowen Ellenen.")
    |> mes("My sworn arch-enemy.")
    |> next()
    |> mes("[Librarian]")
    |> mes("Arch-enemy...?")
    |> mes("Um, uh ^666666*Ahem!*^000000")
    |> mes("All I can tell you is that there was a Crusader by that name.")
    |> next()
    |> mes("[Librarian]")
    |> mes("I'm sorry, but")
    |> mes("I can't tell you")
    |> mes("more than that.")
    |> next()
    |> mes("[Librarian]")
    |> mes("^333333*Cough*^000000")
    |> mes("^666666Nutcase!^000000")
    |> close()
  end

  defp friend(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("A friend...?")
    |> mes("Well, we have a")
    |> mes("record of someone")
    |> mes("named Lohen Phelica.")
    |> next()
    |> mes("[Librarian]")
    |> mes(
      "He retired from the service a few years ago. I'd like to give you his address, but we don't have any of that information."
    )
    |> set_char_var(:god_brising, 12)
    |> close()
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes("Now, may")
    |> mes("I excuse myself?")
    |> mes("Thank you!")
    |> close()
  end

  defp restricted(ctx) do
    ctx
    |> mes("[Librarian]")
    |> mes(
      "All confidential personnel records are kept here in the royal library. However, you need authorization"
    )
    |> mes("for full access.")
    |> close()
  end
end
