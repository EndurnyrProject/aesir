defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.RecruiterForTheBrave do
  @moduledoc """
  The Prontera recruiter who signs brave adventurers up for the Ash-Vacuum expedition and
  sends them to the Aldebaran promotional staff for testing.

  ## Behavior

  - Walks each `ep13_ryu` step through its own lines: 12 points at the alliance manager, 9
    to 11 sends the player on to Lighthalzen, 8 briefs the mission (quest 10064 to 10065,
    `ep13_ryu` 9, and the mode's experience reward), and 1 to 7 points back at the
    promotional staff in Aldebaran.
  - At step 0, or on a fresh character, offers the mission through a Yes/No menu; accepting
    starts quest 10057 and sets `ep13_ryu` to 1, declining ends the dialog with a complaint.

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
        map: "prt_cas",
        x: 207,
        y: 165,
        dir: 5,
        sprite: 109,
        name: "Recruiter for the Brave",
        scope: :renewal
      },
      %{
        map: "prt_castle",
        x: 83,
        y: 67,
        dir: 5,
        sprite: 109,
        name: "Recruiter for the Brave",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      12 -> register_elsewhere(ctx)
      step when step > 8 -> go_to_lighthalzen(ctx)
      8 -> brief_mission(ctx)
      step when step > 0 -> find_promotional_staff(ctx)
      _step -> invite(ctx)
    end
  end

  defp register_elsewhere(ctx) do
    ctx
    |> mes("[Recruiter]")
    |> mes("Why have you come again?")
    |> mes("You'd better go to Schwarzwald to register.")
    |> next()
    |> mes("[Recruiter]")
    |> mes("What? You came to here to convey a story? Go ahead.")
    |> next()
    |> mes("[Recruiter]")
    |> mes(
      "Move to the side. There's a Manager who is dealing with all of us, and is involved in international relations here on Midgard."
    )
    |> next()
    |> mes("[Recruiter]")
    |> mes("Just talk to him.")
    |> close()
  end

  defp go_to_lighthalzen(ctx) do
    ctx
    |> mes("[Recruiter]")
    |> mes("Just go there.")
    |> mes("You can get nothing from me.")
    |> mes("Let's rush to")
    |> mes("^FF0000Lighthalzen^000000, which is the original place for the three kingdoms...")
    |> close()
  end

  defp brief_mission(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Recruiter]")
      |> mes("I've heard of you.")
      |> mes("You've finished the tests from the Promotional Staff?")
      |> next()
      |> mes("[Recruiter]")
      |> mes("You are definitely brave enough to venture to this new land.")
      |> mes("I will now appoint you to detect and have adventures in Ash-Vacuum.")
      |> next()
      |> select(["Ash-Vacuum?"])

    ctx =
      ctx
      |> mes("[Recruiter]")
      |> mes(
        "Hm. That's the code name of the place where you will have your adventure. Frankly, we don't know exactly what it is, but we call it 'Ash-Vacuum'."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes("Believe it or not,")
      |> mes("it's definitely true.")
      |> mes("So listen carefully.")
      |> mes("Please.")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Ash-Vacuum... is a living place... that's totally different from where we are living now."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes("It's an unknown place.")
      |> mes("We don't know what's there,")
      |> mes("or who is living there.")
      |> mes("It's beyond our guess.")
      |> mes("Nobody knows.")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Only the brave, like you, deserve to go there. There will be many dangerous things around you, but you must explore it on behalf of Midgard."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes("Hmm......")
      |> next()
      |> mes("[Recruiter]")
      |> mes("Anyway, I am sure that there are many opportunities for fame and fortune there...")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "First, you should go to ^FF0000Lighthalzen^000000 to register for the United Midgard Alliance. I believe they are meeting at the Rekenber Corporation Headquarters..."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes("You can get a detailed guide, better than me, there. Go there and find him...")
      |> next()
      |> mes("[Recruiter]")
      |> mes("I've done what I can. Go there, and get to it!")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Remember, go to ^FF0000Lighthalzen^000000, then follow the directions of the guide there."
      )
      |> next()
      |> changequest(10064, 10065)
      |> set_char_var(:ep13_ryu, 9)

    ctx
    |> award_exp()
    |> mes("[Recruiter]")
    |> mes("Just go there!")
    |> mes("And listen carefully")
    |> mes("about your mission!")
    |> mes("I'm done here...")
    |> close()
  end

  # The reference pays the smaller reward when `checkre(3)` reports renewal content.
  defp award_exp(ctx) do
    if Rathena.truthy?(checkre(ctx, 3)) do
      getexp(ctx, 66_000, 21_000)
    else
      getexp(ctx, 660_000, 210_000)
    end
  end

  defp find_promotional_staff(ctx) do
    ctx
    |> mes("[Recruiter]")
    |> mes("What're you doing here?")
    |> mes(
      "Just go to ^FF0000Aldebaran^000000, and find the ^FF0000Promotional Staff^000000. As I advised you, you'd better save time."
    )
    |> close()
  end

  defp invite(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Recruiter]")
      |> mes("Brave ones! Come to me!")
      |> mes("Real brave people!")
      |> mes("Would you mind trying a challenging mission?")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "I am a recruiter looking for brave people in Prontera! My goal is to recruit the bravest adventurers for this mission."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes("Would you like to join?")
      |> mes("This is always open to you.")
      |> mes("I know, you're super curious.")
      |> mes("Just try whatever you want.")
      |> next()
      |> select(["Yes, I am interested.", "No, thanks."])

    case choice do
      1 -> accept(ctx)
      2 -> decline(ctx)
      _ -> ctx
    end
  end

  defp accept(ctx) do
    ctx
    |> mes("[Recruiter]")
    |> mes("Oh! Yes! You're quite curious!")
    |> mes("You're a real adventurer.")
    |> mes("A genuine desire for adventure.")
    |> mes("Ok! Let me start by telling you the story of the mission!!")
    |> next()
    |> mes("[Recruiter]")
    |> mes(
      "All of this of course, the Promotional Staff can tell you, but they're not that reliable. So, let me explain to you. Just listen carefully."
    )
    |> next()
    |> mes("[Recruiter]")
    |> mes("Um... There's not that much to tell you...")
    |> mes("...")
    |> next()
    |> mes("[Recruiter]")
    |> mes(
      "The point is that we want someone who is curious and brave, to go to new places. And I choose you!!"
    )
    |> next()
    |> mes("[Recruiter]")
    |> mes(
      "This is a special place among unknown places. Quite special! I can't tell you much just now. Just believe me that it is truly uncommon!"
    )
    |> next()
    |> mes("[Recruiter]")
    |> mes("So, now, let me test you.")
    |> mes("Once I get you qualified,")
    |> mes("I will tell you everything.")
    |> next()
    |> mes("[Recruiter]")
    |> mes(
      "Just go to the ^FF0000Promotional Staff^000000 in Aldebaran and get permission. They can judge you more carefully than me. Go ahead."
    )
    |> next()
    |> mes("[Recruiter]")
    |> mes(
      "They will take care of everything, if you say that you've been sent by the Recruiter in Prontera."
    )
    |> next()
    |> setquest(10057)
    |> set_char_var(:ep13_ryu, 1)
    |> mes("[Recruiter]")
    |> mes("Time is zeny, just go.")
    |> mes(
      "As soon as you visit the Promotional Staff, you will be allowed to travel to the unknown land."
    )
    |> close()
  end

  defp decline(ctx) do
    ctx
    |> mes("[Recruiter]")
    |> mes("Are you seriously enjoying your adventures? You're not that curious.")
    |> next()
    |> mes("[Recruiter]")
    |> mes("Just go about your business!")
    |> next()
    |> mes("[Recruiter]")
    |> mes("-Muttering and complaining...-")
    |> close()
  end
end
