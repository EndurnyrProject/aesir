defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Jenny do
  @moduledoc """
  Jenny is Phobe's mother and a gardener at Sir Zhed's mansion.

  ## Behavior

  - Provides clues and asks the adventurer to find Phobe.
  - Reacts to news of her son as the search progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 48,
        y: 237,
        dir: 3,
        sprite: 894,
        name: "Jenny",
        scope: :shared,
        unique_name: "Jenny#ra_in01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lost_boy, 0) < 3 ->
        turn_away(ctx)

      get_char_var(ctx, :lost_boy, 0) == 3 ->
        discuss_phobe(ctx)

      get_char_var(ctx, :lost_boy, 0) >= 3 and get_char_var(ctx, :lost_boy, 0) < 6 ->
        search_market(ctx)

      get_char_var(ctx, :lost_boy, 0) == 6 ->
        worry(ctx)

      get_char_var(ctx, :lost_boy, 0) > 6 and get_char_var(ctx, :lost_boy, 0) < 11 ->
        ask_about_phobe(ctx)

      get_char_var(ctx, :lost_boy, 0) > 10 and get_char_var(ctx, :lost_boy, 0) < 13 ->
        gratitude(ctx)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Jenny]")
    |> mes("These grounds are owned by")
    |> mes("Sir Zhed and are considered")
    |> mes("private property. Please")
    |> mes("leave immediately if you")
    |> mes("haven't been invited!")
    |> close()
  end

  defp discuss_phobe(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me, but are")
      |> mes("you Jenny? I've been")
      |> mes("told by Manson to speak")
      |> mes("to you if I wanted to learn")
      |> mes("more about Phobe. You see,")
      |> mes("Vincent hired me to find him.")
      |> next()
      |> mes("[Jenny]")
      |> mes("Oh! That's wonderful")
      |> mes("news! Y-yes, I'm Jenny.")
      |> mes("What did you need to know?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Er, anything you could")
      |> mes("tell me would be fine.")
      |> mes("Things like his favorite")
      |> mes("hangouts might also be")
      |> mes("helpful for me to investigate.")
      |> next()
      |> mes("[Jenny]")
      |> mes("Phobe is such a good")
      |> mes("boy. I don't know what")
      |> mes("kind of trouble he's gotten")
      |> mes("into this time, but he's")
      |> mes("really a great kid if you")
      |> mes("just give him a chance.")
      |> next()
      |> mes("[Jenny]")
      |> mes("Oh... Vincent must")
      |> mes("also be--I'm-I'm very")
      |> mes("glad that he's hired")
      |> mes("you. But as for places")
      |> mes("he might be found, I'm")
      |> mes("not sure if I know.")
      |> next()
      |> mes("[Jenny]")
      |> mes("Have you tried the")
      |> mes("market? That's where")
      |> mes("he was last seen, wasn't it?")
      |> mes("Maybe they have some idea")
      |> mes("of where he was going?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh... That's a good idea.")
    |> mes("Alright, I guess I can go")
    |> mes("to the market and ask around.")
    |> set_char_var(:lost_boy, 4)
    |> changequest(8091, 8092)
    |> close()
  end

  defp search_market(ctx) do
    ctx =
      ctx
      |> mes("[Jenny]")
      |> mes("Please find Phobe,")
      |> mes("and bring him back")
      |> mes("safely as soon as you")
      |> mes("can! I can't help but worry")
      |> mes("about that boy, you know?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I'll do my best")
    |> mes("First, I guess I should ask")
    |> mes("around the market where")
    |> mes("Phobe was last seen.")
    |> close()
  end

  defp worry(ctx) do
    ctx
    |> mes("[Jenny]")
    |> mes("Please find Phobe,")
    |> mes("and bring him back")
    |> mes("safely as soon as you")
    |> mes("can! I can't help but worry")
    |> mes("about that boy, you know?")
    |> close()
  end

  defp ask_about_phobe(ctx) do
    ctx =
      ctx |> mes("[Jenny]") |> mes("Oh! You're back!") |> mes("Did you find Phobe?") |> next()

    ctx =
      cond do
        get_char_var(ctx, :lost_boy, 0) == 7 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Actually... Uh...")
          |> mes("I have something very")
          |> mes("important to discuss")
          |> mes("with Vincent first.")

        get_char_var(ctx, :lost_boy, 0) == 8 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Actually... Uh...")
          |> mes("Not just yet. But I'm")
          |> mes("following a really good")
          |> mes("lead! Don't worry, I'll")
          |> mes("find him soon, I promise.")

        get_char_var(ctx, :lost_boy, 0) == 9 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Actually... Uh...")
          |> mes("I should report to")
          |> mes("Vincent first and return")
          |> mes("this jewel, but I'll deliver")
          |> mes("some good news soon,")
          |> mes("I promise. Se eyou later~")

        get_char_var(ctx, :lost_boy, 0) == 10 ->
          ctx =
            ctx
            |> mes(
              Rathena.concat(
                Rathena.concat("[", char_name(ctx, 0)),
                "]"
              )
            )
            |> mes("Yes, he's fine, just")
            |> mes("hanging around the south")
            |> mes("side of town. He's safe,")
            |> mes("but he's not willing to")
            |> mes("come home just right now.")
            |> next()

          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("[", char_name(ctx, 0)),
              "]"
            )
          )
          |> mes("The jewel's been returned,")
          |> mes("so everything should be fine")
          |> mes("now. Also, Vincent explained")
          |> mes("everything to me. You know,")
          |> mes("how you, him, and Phobe")
          |> mes("are all related, so...")
          |> next()
          |> mes("[Jenny]")
          |> mes("Oh! Oh, I see. He told")
          |> mes("you our secret? Well,")
          |> mes("I guess we can trust you.")
          |> mes("Mostly, I'm just relieved")
          |> mes("that my son is alright, and")
          |> mes("that he won't get in trouble.")
          |> next()
          |> mes("[Jenny]")
          |> mes("Anyway, even though Phobe")
          |> mes("is being pretty stubborn,")
          |> mes("I'm sure he'll come back")
          |> mes("soon. As he grows up, I think")
          |> mes("he'll understand his father's")
          |> mes("position a little bit better.")
          |> next()
          |> mes("[Jenny]")
          |> mes("I hope so. Although")
          |> mes("it's been very hard for")
          |> mes("all three of us to live")
          |> mes("this way, I couldn't be")
          |> mes("happier. Thank you for")
          |> mes("all of your help, adventurer~")
          |> set_char_var(:lost_boy, 11)
          |> changequest(8097, 8098)

        true ->
          ctx
      end

    close(ctx)
  end

  defp gratitude(ctx) do
    ctx
    |> mes("[Jenny]")
    |> mes("Thank you so much for")
    |> mes("finding my son. If there's")
    |> mes("anything I can ever do for")
    |> mes("you, please let me know.")
    |> mes("You don't know how grateful")
    |> mes("I am to you as a mother...")
    |> close()
  end
end
