defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.Representative do
  @moduledoc """
  Marlin Putiur represents the Monster Research Organization.

  ## Behavior

  She discusses an organization member or helps players find bards depending on quest progress.

  ## Credits

  Original rAthena authors: Riotblade and L0ne_W0lf.
  Contributors: Lupus, SinSloth, and Euphy.

  ## Adaptation

  Transpiled by `mix aesir.import.npcs` and refactored with LLM assistance.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 20,
        y: 123,
        dir: 7,
        sprite: 95,
        name: "Representative",
        scope: :shared,
        unique_name: "Representative#bq"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Marlin Putiur]")

    ctx =
      if get_char_var(ctx, :god_brising, 0) == 3 do
        ctx =
          ctx
          |> mes("Welcome to the")
          |> mes("Monster Research")
          |> mes("Organization.")
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes(
            "We are researching monsters based upon information from adventurers in order to efficiently cope with monsters out in the wild."
          )
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("We're accepting any kind of information related to monsters,")
          |> mes("so if you have any news or info, please don't hesitate to submit it to me.")
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("You can use the report documentation form in")
          |> mes("this room at your convenience.")
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("Eh...?")
          |> mes("Did you just say")
          |> mes("you're looking for")
          |> mes("someone? Well...")
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("Well, if he's a registered")
          |> mes("member of this organization,")
          |> mes("I can help you.")
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("What was the name?")
          |> mes("Hermite Charles...?")
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("Oh, I found him.")
          |> mes(
            "Errr, but he didn't submit all of the required information when he applied for membership..."
          )
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("Oh. He's a Rogue.")
          |> mes("Well, that explains everything. Anyway, did you want to see all")
          |> mes("the information we have?")
          |> next()
          |> mes("^3355FFMarlin shows you")
          |> mes("the membership")
          |> mes("application card.^000000")
          |> next()
          |> mes("[Membership Card]")
          |> mes("Name: Hermite Charles")
          |> mes("Job: Rogue")
          |> mes("Sex: Rogue")
          |> mes("Address: Yo Mama Street, Prontera")
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes(
            "Unfortunately, we don't have any more information. But I hope this will be helpful to you in some way."
          )
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes("Still, it may be a good idea to visit the Rogue Guild. Perhaps")
          |> mes("they can help you.")
          |> close()

        throw({:script_end, ctx})
      else
        ctx
      end

    ctx =
      ctx
      |> mes("Welcome to the")
      |> mes("Monster Research")
      |> mes("Organization.")
      |> next()
      |> mes("[Marlin Putiur]")
      |> mes(
        "We are researching monsters based on information from adventurers in order to efficiently cope with monsters out in the wild."
      )
      |> next()
      |> mes("[Marlin Putiur]")
      |> mes(
        "We're accepting any kind of information related to monsters, so if you have any news or info, please don't hesitate to submit it to me."
      )
      |> next()
      |> mes("[Marlin Putiur]")
      |> mes("You can use the report documentation form in this room at your convenience.")

    if get_char_var(ctx, :gef_bard_q, 0) == 4 or get_char_var(ctx, :gef_bard_q, 0) == 24 do
      {ctx, name} =
        ctx
        |> next()
        |> mes("[Marlin Putiur]")
        |> mes("Hmmm?")
        |> mes("Adventurers of this organization? Ah, you say you're looking for a Bard?")
        |> next()
        |> mes("[Marlin Putuir]")
        |> mes(
          "Yes, we have a few Bard members who regularly send us information related to monsters."
        )
        |> next()
        |> mes("[Marlin Putiur]")
        |> mes(
          "I also hear the Bards have been helping scholars instill bulletin boards in fields which indicate the location for new adventurers. Would you let me know the full name of the person you're looking for?"
        )
        |> next()
        |> input(:string)

      ctx = set_local(ctx, :"inputstr$", name)

      if get_local(ctx, :"inputstr$", "") == "Minty Errende" do
        ctx
        |> mes("[Marlin Putiur]")
        |> mes("Minty Errende...")
        |> mes(
          "Oh yes, I remember him. He told me a while ago that he's heading South, and that he's staying in Geffen now."
        )
        |> next()
        |> mes("[Marlin Putiur]")
        |> mes(
          "He's a very kind, friendly person. Errende's always doing his best to provide us with the information we need. When you get a chance, would you please give him my regards?"
        )
        |> close()
      else
        if get_local(ctx, :"inputstr$", "") == "Kino Kitty" do
          ctx
          |> mes("[Marlin Putiur]")
          |> mes(
            "Kino Kitty, Kino Kitty... Oh, here we are. He sent us a letter that says, 'I will stay in the desert until I find my real self.'"
          )
          |> next()
          |> mes("[Marlin Putiur]")
          |> mes(
            "He doesn't seem healthy, but I guess he's still traveling. Trying seeking him out in Morocc, and give my regards to him if you get the chance."
          )
          |> close()
        else
          if get_local(ctx, :"inputstr$", "") == "Gunther Doubleharmony" do
            ctx
            |> mes("[Marlin Putiur]")
            |> mes(
              "Ah, are you a friend of Gunther's? Haha, he's a very funny guy, if a little excitable. Let's see, Gunther, Gunther..."
            )
            |> next()
            |> mes("[Marlin Putiur]")
            |> mes(
              "Ah, it says here that he wanted to look around Payon and Alberta. So he'll be at one of those places. I'm sorry I can't be more specific."
            )
            |> close()
          else
            ctx = mes(ctx, "[Marlin Putiur]")

            ctx
            |> mes(Rathena.concat(Rathena.concat(" ", get_local(ctx, :"inputstr$", "")), "...?"))
            |> mes("Ummm hmm...")
            |> mes("I'm sorry, but we don't have any records for that person.")
            |> close()
          end
        end
      end
    else
      ctx
      |> next()
      |> mes("[Marlin Putiur]")
      |> mes(
        "We are endeavoring to research monsters in this world with the intent to aid each and every adventurer on their journeys."
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
