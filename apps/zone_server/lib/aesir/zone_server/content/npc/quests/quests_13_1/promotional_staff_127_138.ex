defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.PromotionalStaff127138 do
  @moduledoc """
  The Aldebaran promotional staff, who runs the Jellopy test in the middle of the Ash-Vacuum
  recruitment.

  ## Behavior

  - Runs one stage of the recruitment per `ep13_ryu` step: the shared pitch on step 0, the
    300 Jellopy assignment on step 1 (quest 10057 to 10058), the delivery on step 2 (consumes
    300 Jellopy, quest 10058 to 10059, step 3), and the Geffen directions on step 3.
  - Past step 3 asks how the adventure is going.

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
        map: "aldebaran",
        x: 127,
        y: 138,
        dir: 3,
        sprite: 100,
        name: "Promotional Staff",
        scope: :shared,
        unique_name: "Promotional Staff#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @jellopy 909
  @jellopies_needed 300

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      step when step > 3 -> already_adventuring(ctx)
      3 -> go_to_geffen(ctx)
      2 -> jellopy_delivery(ctx)
      1 -> first_test(ctx)
      _step -> shared_pitch(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp already_adventuring(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("Did you try out for the test, or are you already enjoying your adventures?")
    |> close()
  end

  defp go_to_geffen(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes(
      "Just visit the ^FF0000Promotional Staff in Geffen^000000. You have no business with me anymore. Bless you. I wish you a safe adventure."
    )
    |> close()
  end

  defp jellopy_delivery(ctx) do
    if count_item(ctx, @jellopy) < @jellopies_needed do
      short_on_jellopy(ctx)
    else
      takes_jellopy(ctx)
    end
  end

  defp short_on_jellopy(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("Don't forget to bring... ^FF0000300 Jellopy^000000.")
    |> mes("Got it? ^FF0000300 Jellopy^000000!")
    |> mes("Let me know once you got them.")
    |> close()
  end

  defp takes_jellopy(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("Hey! Let me know once you collect all of them.")
    |> mes("Don't disturb me anymore. I'm a busy man... What a waste.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Hm? Did you bring all of them?")
    |> mes("No! It's quite an annoying job")
    |> mes("I'm impressed that you managed to do such a menial thing to bring 300 Jellopy!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("You have guts kid!")
    |> mes("You're a good-willed person!")
    |> mes("Ok, you win!")
    |> mes("You pass!!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Adventurers like you")
    |> mes("are not common")
    |> mes("A hard-boiled soldier!")
    |> mes("Stronger than me!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Now can you go to the")
    |> mes("Promotional Staff in Geffen?")
    |> mes("He will test you again.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("You know this isn't an easy quest.")
    |> mes("You resolved to carry it out, didn't you?")
    |> mes("Brace yourself for it.")
    |> next()
    |> delitem(@jellopy, @jellopies_needed)
    |> changequest(10058, 10059)
    |> set_char_var(:ep13_ryu, 3)
    |> mes("[Promotional Staff]")
    |> mes("Anyway you did the first step.")
    |> mes("Bless you!")
    |> close()
  end

  defp first_test(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Promotional Staff]")
      |> mes(
        "We want the adventurers who are super curious and extremely brave. Join us for a wonderful adventure!"
      )
      |> next()
      |> mes("[Promotional Staff]")
      |> mes("Hey, you're a well-versed person, right? Are you interested in my story?")
      |> next()
      |> select(["I have something for you."])

    ctx
    |> mes("[Promotional Staff]")
    |> mes("For me??")
    |> mes("I hate annoying stuff.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Ahh... I sensed that I would get your request.")
    |> mes("The recruiter sent you here to get tested?")
    |> mes("Hmm.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Ah! They always push me,")
    |> mes("to suffer from so much work")
    |> mes("I live a hard life!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("My job is testing if you are strong and brave enough for this adventure.")
    |> mes("What a bother!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("I will accept you if you bring me ^FF0000300 Jellopy^000000.")
    |> mes("I believe that you can bring them to me.")
    |> mes("Are you ready?")
    |> next()
    |> changequest(10057, 10058)
    |> set_char_var(:ep13_ryu, 2)
    |> mes("[Promotional Staff]")
    |> mes("Just go ahead and hunt monsters, or whatever and collect 300 jellopies.")
    |> mes("Then we can go forward.")
    |> close()
  end

  defp shared_pitch(ctx) do
    {ctx, _} = Aesir.ZoneServer.Content.Npc.Functions.PromotionalStaff.call(ctx, [])
    ctx
  end
end
