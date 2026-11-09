defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Moc2B1Gate do
  @moduledoc """
  The side door into the Morocc hideout's basement, where Rayan's gang is overheard turning
  on him.

  ## Behavior

  - At `mao_morocc2` step 17 the player overhears Rayan's gang turn on him, then uses a
    Butterfly Wing: the step becomes 18 and quest 7026 advances to 7027.
  - At step 19 the door is open and offers a two-option menu: entering warps into the basement,
    declining closes the dialog.
  - On every other step the door is locked.

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
        map: "que_dan02",
        x: 21,
        y: 37,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#moc2_b1_gate",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @basement {"que_dan02", 91, 11}

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: inspect_door(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: inspect_door(ctx)

  defp inspect_door(ctx) do
    case get_char_var(ctx, :mao_morocc2, 0) do
      17 -> overhear_dispute(ctx)
      19 -> open_door(ctx)
      _step -> locked_door(ctx)
    end
  end

  defp overhear_dispute(ctx) do
    ctx =
      ctx
      |> mes("- You find a side door that leads to the basement.")
      |> mes("A faint light is shining through the hinges.")
      |> mes("There are people inside, talking loudly. -")
      |> next()
      |> mes("[Male Voice]")
      |> mes("Hey Rayan, say something.")
      |> mes("We did everything you asked,")
      |> mes("but...")
      |> next()
      |> mes("[Male Voice]")
      |> mes("...This is totally wrong.")
      |> mes("We did something that we shouldn't have.")
      |> mes("Come on, reconsider this.")
      |> next()
      |> mes("[Male Voice]")
      |> mes("Rayan, Rayan!")
      |> mes("All we wanted was just to shake up the town just a little bit,")
      |> mes("not summon Satan Morocc! The ritual failed like we first planned, but...")
      |> next()
      |> mes("[Voices]")
      |> mes("That's right. It failed, but what happened? Satan Morocc resurrected himself.")
      |> mes("He'll bring the end of this world.")
      |> mes("What have we done?!")
      |> mes("We can't even go back to our country now!")
      |> next()
      |> mes("[Anxious Voice]")
      |> mes(
        "...We all knew that we would be disposed after we stopped being useful.. Just like pawns in a chess match."
      )
      |> mes("But I'm curious.")
      |> mes("Rayan...")
      |> next()
      |> mes("[Anxious Voice]")
      |> mes("Rayan, say something!")
      |> mes("What the hell's wrong with you?")
      |> mes("Why, can't you still forget the Assassin?")
      |> mes("...Hey, tell us. What should we do now?")
      |> next()
      |> mes("[Anxious Voice]")
      |> mes("Let me ask you one question.")
      |> mes("...Did you... Did you really summon Satan Morocc?")
      |> mes("Did you?")
      |> mes("Did you really ask us to help you resurrect Satan Morocc?!")
      |> next()
      |> mes("[Anxious Voice]")
      |> mes("If your silence means yes, I'm out!")
      |> mes("I didn't know then, but I know now. I'm leaving!")
      |> next()
      |> mes("[Rayan]")
      |> mes("Incompetent weaklings.")
      |> mes("I don't need you anymore.")
      |> mes("Thank you for following my lead so far.")
      |> mes("But you're nothing but puppets of the goddess.. *Giggle Giggle*")
      |> next()
      |> mes("[Male Voice]")
      |> mes("Hey, hey! What are you doing?!")
      |> mes("Why are you doing this?!")
      |> next()
      |> mes("- You hear loud thuds and thumping in the midst of their yelling and screaming.")
      |> mes("It sounds like they're having a serious dispute.-")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("...Rayan? ...Morocc? ...Resurrect...?")
      |> mes("I have no idea what they're talking about. Why are they fighting?")
      |> next()
      |> mes("[Rayan]")
      |> mes("You ignorant puppets..")
      |> mes("You're too stupid to understand my master's great will...")
      |> mes("...Oh, right. I completely forgot about 'it.' It's time to take it back.")
      |> mes("What do you say? *Giggle Giggle*")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What the?! Does he know I'm here?!")
    |> mes("I'd better run!")
    |> next()
    |> mes("- You used a Butterfly Wing.-")
    |> set_char_var(:mao_morocc2, 18)
    |> changequest(7026, 7027)
    |> close()
    |> warp(:save_point)
  end

  defp open_door(ctx) do
    {ctx, choice} =
      ctx
      |> mes("- The side to the basement is open.")
      |> mes("You can enter if you want. -")
      |> next()
      |> select(["Enter.", "Do not enter."])

    case choice do
      1 -> warp(ctx, elem(@basement, 0), elem(@basement, 1), elem(@basement, 2))
      2 -> ctx |> mes("You have decided to not enter the basement.") |> close()
      _ -> ctx
    end
  end

  defp locked_door(ctx) do
    ctx
    |> mes("- This door seems to lead to the basement,")
    |> mes("but it's locked pretty securely. -")
    |> close()
  end
end
