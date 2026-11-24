defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Book do
  @moduledoc """
  Contains a mercenary soldier’s journal.

  ## Behavior

  - Lets the player read journal pages and advances the rebellion quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hu_in01", x: 317, y: 312, dir: 0, sprite: 111, name: "Book", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, "hg_book.bmp", 2)

    if get_char_var(ctx, :hg_tre, 0) > 47 do
      {ctx, choice} =
        ctx
        |> mes("- You picked up a very thick book. -")
        |> mes("- You opened the book and found out -")
        |> mes("- that there were a small book hidden behind.-")
        |> next()
        |> select(["Read the small book.", "Leave it alone."])

      case choice do
        1 ->
          ctx
          |> mes("- You picked up the small book. -")
          |> mes("- The book owner must want to -")
          |> mes("- keep it secret. -")
          |> next()
          |> read_pages()

        2 ->
          close_book(ctx)

        _ ->
          ctx
      end
    else
      ctx
    end
  end

  defp read_pages(ctx) do
    {ctx, page} =
      select(ctx, [
        "Page 1",
        "Page 2",
        "Page 3",
        "Page 4",
        "Page 5",
        "Page 6",
        "Page 7",
        "Page 8",
        "Page 9",
        "Stop Reading."
      ])

    case page do
      10 -> close_book(ctx)
      page when page in 1..9 -> ctx |> read_page(page) |> read_pages()
      _ -> ctx
    end
  end

  defp close_book(ctx), do: ctx |> mes("- You closed the book. -") |> close() |> cutin("", 255)

  defp read_page(ctx, page) do
    case page do
      1 ->
        ctx
        |> mes("- You started reading the 1st page of the book. -")
        |> next()
        |> mes("Date: **month **day")
        |> mes("I was told that Rekenber succeeded")
        |> mes("in creating a type of machine called ^FF0000Guardian^000000.")
        |> mes("I have a bad feeling about that, so I decided to write a journal")
        |> mes("starting from today and keep everything in record.")
        |> mes(" ")
        |> mes("\"^FF0000Guardian^000000\" is an android")
        |> mes("that was created based on the idea of \"^3131FFGiantes^000000\",")
        |> mes("the giant tribe that was said to live in an ancient age.")
        |> mes("It is memorized with various commands,")
        |> mes("so it is said to handle difficult things for humans as protecting")
        |> mes("important facilities and such.")
        |> mes(" ")
        |> mes("However, those things are our job, the mercenary soldiers' job.")
        |> mes("Mercenary soldier groups in many areas")
        |> mes("are already agitated by the news of the Guardian creation.")
        |> mes("I am worried what is going to happen to us.")
        |> next()
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()

      2 ->
        ctx
        |> mes("- You started reading the 2nd page of the book. -")
        |> next()
        |> mes("Date: **month **day")
        |> mes("Everybody in this place seems to be very confused and upset as well as me.")
        |> mes("I made a stupid mistake to slip on one of the stairs")
        |> mes("while absent-mindedly walking down. I really need to straighten myself out.")
        |> next()
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()

      3 ->
        ctx
        |> mes("- You started reading the 3rd page of the book. -")
        |> next()
        |> mes("Date: **month **day")
        |> mes("Today, we, \"Republic Garrison\",")
        |> mes("were introduced to ^3131FF2 Guardians.")
        |> mes("Those machines joined us for their test operation^000000.")
        |> mes("Everyone seemed to be intimidated by their big and heavy frames.")
        |> mes("I thought that these machines were supposed to aid humans in doing")
        |> mes("hard works. But it doesn't seem to be true.")
        |> mes("To me, they are nothing but \"^FF0000weapons of mass destruction^000000\".")
        |> mes("Perhaps, they might be intended to be that way from the beginning.")
        |> mes(" ")
        |> mes("What is going to be next after we finish testing the machines?")
        |> mes("No matter how bad other people criticize us for being greedy toward money,")
        |> mes("we always take pride in what we are doing, and we always do our best.")
        |> mes("We must try our best to do our job, otherwise we will be dead right away.")
        |> mes("But, now, we are losing our place to the lifeless machines.")
        |> mes("Many people have quit this job after the machines were introduced.")
        |> mes("I must admit that I am also being shaken by the thought.")
        |> mes(" ")
        |> mes(
          "Bah, god damn you, Rekenber! You just have created the worst invention in history!"
        )
        |> next()
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()

      4 ->
        ctx
        |> mes("- You started reading the 4th page of the book. -")
        |> next()
        |> mes("Date: **month **day")
        |> mes("No one wouldn't know how boring it is to mount guard with a machine.")
        |> next()
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()

      5 ->
        ctx
        |> mes("- You started reading the 5th page of the book. -")
        |> next()
        |> mes("Date: **month **day")
        |> mes("Damn it! Finally it happened today!")
        |> mes("Today, our troops was in total disorder.")
        |> mes("One of the guardians caused an error and brought havoc.")
        |> mes("While we were terrified and didn't know what to do, that broken guardian")
        |> mes("crushed the commander of 'Blade Canine Mercenary' to death.")
        |> mes(" ")
        |> mes("I can't remember how we could regain control over the broken guardian.")
        |> mes(
          "My mind is still baffled for the fact that that machine actually killed an innocent guy as I was kind of worried about."
        )
        |> mes(
          "Many people were dispatched from Rekenber to investigate this matter, so hopefully they will figure out"
        )
        |> mes("what the hell was wrong with that machine.")
        |> mes(
          "But, it is not going to change the fact that one of our comrade was taken his life by that merciless machine,"
        )
        |> mes("and no once can replace his place for his family.")
        |> next()
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()

      6 ->
        {ctx, choice} =
          ctx
          |> mes("- You started reading the 6th page of the book. -")
          |> next()
          |> mes("Date: **month **day")
          |> mes("We received a message from upper management.")
          |> mes(
            "\"^3131FFKeep our mouth from spreading the story to outside.^000000\", that's the content of message."
          )
          |> mes("Rekenber must have bribed the upper management of our troops with money.")
          |> mes(
            "Otherwise, why would they want us to keep our mouth sealed about a such shocking incident?"
          )
          |> mes(
            "We, angry mercenary soldiers burst into rage right after the morning session was over."
          )
          |> mes(" ")
          |> mes(
            "We went ahead and spread the story about the shocking incident to every mercenary troops."
          )
          |> mes("And then we destroyed every guardian which we found in hangars.")
          |> mes(
            "The sounds of hammering metal and sirens were echoing everywhere, everywhere you went."
          )
          |> mes(" ")
          |> mes("...We took refuge in a safe place out of our unit because of what happened.")
          |> mes(
            "We are planning to assert our social security to the public and inform the public with"
          )
          |> mes(
            "the danger of the guardians and the negligence of the government and Rekenber toward the incident."
          )
          |> mes("Our leader told us that he has sent out letters to every mercenary troop")
          |> mes("to encourage them to participate in what we are trying to do.")
          |> mes(" ")
          |> mes("I feel like...that I have just turn into a no-way-out.")
          |> mes("I am facing my future with a deep sense of gloom.")
          |> next()
          |> mes("- You found a folded note between the pages that you were reading. -")
          |> next()
          |> select(["Check the note.", "Read the next page."])

        if choice == 1 do
          ctx
          |> mes("^3131FF.........................^000000")
          |> next()
          |> mes("^3131FF...I am so sorry for hearing such devastating news and for your loss.")
          |> mes("Every member of our troops are already aware of the shocking incident,")
          |> mes("and all of us are uncontrollably enraged.")
          |> mes("The government has been bribed ")
          |> mes("with Rekenber's filthy money and has become nothing but a puppet.")
          |> mes("We must take control over our life once again. Our future depends on us.")
          |> mes("We will join you, 'Blade Canine Mercenary' to fight for our rights.^000000")
          |> next()
          |> mes("^3131FF.........................^000000")
          |> next()
        else
          ctx
        end

      7 ->
        ctx
        |> mes("- You started reading the 7th page.-")
        |> next()
        |> mes("Date: **month **day")
        |> mes("Our firm will was not enough.")
        |> mes("Our desperate effort was not enough!")
        |> mes("Many mercenary groups joined us to fight with the government and Rekenber.")
        |> mes(
          "But we were too weak to compete with their invincible guardians. We were literally swept away."
        )
        |> mes(
          "They were quicker than we expected in taking action, and lines and lines of guardians were coming after us."
        )
        |> mes(
          "There was nothing that we could do. We met with a disastrous defeat in the battle with guardians."
        )
        |> mes(" ")
        |> mes("Everybody is still in shock, but we can't give up now.")
        |> mes(
          "I think that we are going to visit a house of a sage called \"Varmunt\" early in the morning."
        )
        |> mes("I don't know why, but it seems that the sage is against the use of guardians.")
        |> mes("People say that his mansion is rather like a fortress.")
        |> mes("I also don't know why someone would want to build his house")
        |> mes(
          "as strong as a fortress. Regardless, I am pretty sure that his support will be a great help for us."
        )
        |> mes("It was a really tiring day today. It was also a very chaotic day.")
        |> mes("To be honest, I don't know what is going to happen now.")
        |> mes("I am scared if I would die helplessly. I am scared and depressed.")
        |> mes(
          "Why must this happen to us, and what have we done to deserve such a horrible treatment?"
        )
        |> next()
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()

      8 ->
        ctx
        |> mes("- You started reading the 8th page. -")
        |> next()
        |> mes("Date: **month **day")
        |> mes(
          "Our leader became desperate, so he sent a request to Schwarzwald Republic for ^3131FFa cease-fire agreement^000000."
        )
        |> mes("I guess that he was frightened by guardians around the Varmunt mansion.")
        |> mes("Sadly, Schwarzwald Republic declined our request without hesitation.")
        |> mes(
          "They stated through their reponse that ^FF0000they would not tolerate this kind of unacceptable rebellion by any means,"
        )
        |> mes("and thus, they would take strong action against the rebellion this time.^000000.")
        |> mes(
          "I guess that the government is determined to eliminate us, the mercenary soldiers through this event."
        )
        |> mes(
          "People now started showing their resentment toward us, who brought disorder to their country."
        )
        |> mes(
          "This is not right. Something has went wrong. We just wanted the government to secure our lives, that was all."
        )
        |> mes(
          "Since we were declined for a cease-fire agreement, we are planning to hold the last fight tomorrow in this place."
        )
        |> next()
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()

      9 ->
        ctx =
          ctx
          |> mes("- You started reading the 9th page. -")
          |> next()
          |> mes("Date: **month **day")
          |> mes("It has been a while since I wrote a journal last time.")
          |> mes("I am in Hugel, a small town at the border of Schwarzwald Republic.")
          |> mes(
            "Because of the locational penalty, people of this town seldom see outsiders, and if they see one, they treate them warmheartedly."
          )
          |> mes(
            "Although I didn't have a time to write a journal that time, the last fight in the Varmunt mansion turned out to be our miserable defeat...as I was worried."
          )
          |> mes(
            "I was told that Sage Varmunt disappeared after the fight, and all of his documents were taken by Rekenber."
          )
          |> mes(
            "I am afraid that they might create a more powerful version of the existing guardian by using his documents."
          )
          |> mes(" ")
          |> mes("I lost one arm during the last fight, and I barely escaped to Hugel.")
          |> mes(
            "I feel so lucky to be in Hugel, because when I arrived, I was a total mess with only one arm,"
          )
          |> mes("but the people in this town did not ask me anything but welcomed me.")
          |> mes(" ")
          |> mes(
            "I have nowhere to go any longer. I am planning to live my life here as long as nothing happens soon."
          )
          |> mes(" ")
          |> mes(
            "My arm is throbbing with pain again. The history of mercenary soldiers ended, and I need to rest."
          )
          |> mes("I hope that this will be the last page of my journal.")

        ctx =
          if get_char_var(ctx, :hg_tre, 0) == 48 do
            set_char_var(ctx, :hg_tre, 49)
          else
            ctx
          end

        ctx |> next() |> mes("- The journal was ended at the page. -") |> next()
    end
  end
end
