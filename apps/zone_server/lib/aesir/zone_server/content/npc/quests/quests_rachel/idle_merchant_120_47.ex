defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.IdleMerchant12047 do
  @moduledoc """
  A merchant who passes along a message about Phobe.

  ## Behavior

  - Directs the search for Phobe toward the ice cave.

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
        x: 120,
        y: 47,
        dir: 3,
        sprite: 85,
        name: "Idle Merchant",
        scope: :shared,
        unique_name: "Idle Merchant#ra_in01_2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lost_boy, 0) < 5 or get_char_var(ctx, :lost_boy, 0) > 6 -> idle(ctx)
      get_char_var(ctx, :lost_boy, 0) == 5 -> deliver_message(ctx)
      get_char_var(ctx, :lost_boy, 0) == 6 -> repeat_message(ctx)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp idle(ctx) do
    ctx
    |> mes("[Idle Merchant]")
    |> mes("I'm thinking of quitting")
    |> mes("this business... No one")
    |> mes("to seems to want whatever")
    |> mes("I'm selling! I definitely can't")
    |> mes("make a living like this.")
    |> close()
  end

  defp deliver_message(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me,")
      |> mes("um... Hello?")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("Oh! Welcome to my shop!")
      |> mes("How can I help you today?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Actually, I'm not")
      |> mes("here to buy anything...")
      |> mes("I'm looking for a boy")
      |> mes("named Phobe that was")
      |> mes("here a few days ago.")
      |> mes("Have you seen him?")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("Oh! Yeah, last night,")
      |> mes("some guy asked me to tell")
      |> mes("anyone looking for this guy")
      |> mes("named Phobe to give you")
      |> mes("a message. Basically, he wants")
      |> mes("you to come to the ''ice cave.''")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Who asked you to tell")
    |> mes("me that? How did he know")
    |> mes("that I'd come over here?")
    |> mes("Does he know where Phobe")
    |> mes("is? I-Is Phobe alright?")
    |> next()
    |> mes("[Idle Merchant]")
    |> mes("No clue. I told you all")
    |> mes("I know. Let's see, his")
    |> mes("name was... Nogan?")
    |> mes("Rogan? Something")
    |> mes("like that. That's")
    |> mes("all I know, honest.")
    |> next()
    |> mes("[Idle Merchant]")
    |> mes("So the kid's missing,")
    |> mes("huh? Good luck finding")
    |> mes("him. Oh, and be careful")
    |> mes("in that ice cave. That place")
    |> mes("can be plenty dangerous.")
    |> set_char_var(:lost_boy, 6)
    |> changequest(8092, 8093)
    |> close()
  end

  defp repeat_message(ctx) do
    ctx =
      ctx
      |> mes("[Idle Merchant]")
      |> mes("So yeah, last night,")
      |> mes("some guy asked me to tell")
      |> mes("anyone looking for this guy")
      |> mes("named Phobe to give you")
      |> mes("a message. Basically, he wants")
      |> mes("you to come to the ''ice cave.''")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Who asked you to tell")
    |> mes("me that? How did he know")
    |> mes("that I'd come over here?")
    |> mes("Does he know where Phobe")
    |> mes("is? I-Is Phobe alright?")
    |> next()
    |> mes("[Idle Merchant]")
    |> mes("No clue. I told you all")
    |> mes("I know. Let's see, his")
    |> mes("name was... Nogan?")
    |> mes("Rogan? Something")
    |> mes("like that. That's")
    |> mes("all I know, honest.")
    |> next()
    |> mes("[Idle Merchant]")
    |> mes("So the kid's missing,")
    |> mes("huh? Good luck finding")
    |> mes("him. Oh, and be careful")
    |> mes("in that ice cave. That place")
    |> mes("can be plenty dangerous.")
    |> close()
  end
end
