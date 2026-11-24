defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.CampgroundBoy do
  @moduledoc """
  Rochito enjoys a barbeque with his friends at the campground.

  ## Behavior

  - Sends the adventurer between his group and the Chief with seasoning and wine.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 206,
        y: 310,
        dir: 4,
        sprite: 704,
        name: "Campground Boy",
        scope: :shared,
        unique_name: "Campground Boy#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        0 ->
          {ctx, choice} =
            ctx
            |> mes("[Rochito]")
            |> mes("Bread, fruits, vegetables...")
            |> mes("Bleh. All that other food is")
            |> mes("nothing compared to the ")
            |> mes("hearty flavor of meat. Yeap,")
            |> mes("BBQ camping in Comodo is")
            |> mes("heaven to a meat lover like me~")
            |> next()
            |> select(["BBQ Camping...?", "Cancel"])

          if choice == 1 do
            ctx
            |> mes("[Rochito]")
            |> mes("Yeah man... You can eat")
            |> mes("Komodoru meat all day when")
            |> mes("you go BBQ camping. Komodoru")
            |> mes("is an animal native to Comodo")
            |> mes("and every part of it is delicious. Every. Single. Morsel.")
            |> next()
            |> mes("[Rochito]")
            |> mes("What makes this meat even")
            |> mes("more delicious is the special")
            |> mes("Koserahserah seasoning they")
            |> mes("use. That stuff is almost...")
            |> mes("addictive. Without it, we")
            |> mes("can't start our barbeque!")
            |> next()
            |> mes("[Rochito]")
            |> mes("If we settled on anything")
            |> mes("less than the very best BBQ,")
            |> mes("then our comrades that died")
            |> mes("to help ^FF0000banish that witch^000000 would")
            |> mes("surely be ashamed of us!")
            |> next()
            |> mes("[Rochito]")
            |> mes("Say, would you do us a favor?")
            |> mes("The Chief of Comodo was going")
            |> mes("to bring the Koserahserah and")
            |> mes("join us for our barbeque, but")
            |> mes("we're guessing he's got to")
            |> mes("cancel because of his duties.")
            |> next()
            |> mes("[Rochito]")
            |> mes("Let's see, our Chief lives to")
            |> mes("the west of these campgrounds.")
            |> mes("Would you visit him and see")
            |> mes("what's taking him so long")
            |> mes("to get over here?")
            |> set_char_var(:dmdswrd_Q, 1)
          else
            ctx
            |> mes("[Rochito]")
            |> mes("You know, people gather")
            |> mes("on these campgrounds in")
            |> mes("memory and respect of those")
            |> mes("that have fallen in battle")
            |> mes("against the witch of Comodo.")
            |> next()
            |> mes("[Rochito]")
            |> mes("Long before Comodo was")
            |> mes("built inside this huge cave,")
            |> mes("this witch used to live in here. A lot of people died trying to")
            |> mes("get rid of her, but there're rumors that she's still around...")
          end

        1 ->
          ctx
          |> mes("[Rochito]")
          |> mes("Komodoru meat is especially")
          |> mes("great when it's seasoned with")
          |> mes("Koserahserah. That flavoring")
          |> mes("is one of Comodo's claims to")
          |> mes("fame! You should try some~")
          |> next()
          |> mes("[Rochito]")
          |> mes("Speaking of which, our Chief")
          |> mes("still hasn't come and brought")
          |> mes("the Koserahserah! Would you")
          |> mes("see what's taking him so long?")
          |> mes("His house is located west of")
          |> mes("these campgrounds.")

        2 ->
          ctx
          |> mes("[Rochito]")
          |> mes("Oh, hey, you're back.")
          |> mes("Did you speak to our")
          |> mes("Chief? Don't tell me")
          |> mes("he had to cancel--we've")
          |> mes("been planning this outing")
          |> mes("with him for a quite a while...")
          |> next()
          |> mes("^3355FFYou give Rochito the")
          |> mes("Koserahserah seasoning,")
          |> mes("and explain why the Chief")
          |> mes("cannot attend the barbeque.^000000")
          |> next()
          |> mes("[Rochito]")
          |> mes("Awww, nuts. I guess he's")
          |> mes("got responsbilities, but it's")
          |> mes("still a little disappointing.")
          |> mes("He's a buddy, after all. Well,")
          |> mes("at least he was kind enough")
          |> mes("to send the Koserahserah.")
          |> next()
          |> mes("[Rochito]")
          |> mes("It's really too bad that")
          |> mes("he can't join us. Ah, I've got")
          |> mes("an idea! Would you please bring")
          |> mes("this bottle to Tausupa, er, our")
          |> mes("Chief? It's Mureuchieligu, a")
          |> mes("special vintage wine~")
          |> next()
          |> mes("^3355FFYou've received a bottle")
          |> mes("of Mureuchieligu wine to")
          |> mes("deliver to the Comodo Chief.^000000")
          |> set_char_var(:dmdswrd_Q, 3)

        3 ->
          ctx
          |> mes("[Rochito]")
          |> mes("I know that I should be")
          |> mes("delivering that bottle of")
          |> mes("wine to the Chief myself,")
          |> mes("but I've got to tend to this")
          |> mes("barbeque. I hope you ")
          |> mes("understand...")
          |> next()
          |> mes("[Rochito]")
          |> mes("Anyway, you'd be doing")
          |> mes("me a huge favor if you")
          |> mes("spoke to the Chief, and gave")
          |> mes("him my thanks, along with")
          |> mes("that bottle of Mureuchieligu.")

        _ ->
          ctx
          |> mes("[Rochito]")
          |> mes("Oh, hey there~")
          |> mes("Thanks for helping us")
          |> mes("out earlier. I wish the")
          |> mes("Chief would join us in our")
          |> mes("barbeque, but I understand")
          |> mes("that he has to protect Comodo.")
          |> next()
          |> mes("[Rochito]")
          |> mes("Hey, you know what?")
          |> mes("I can't exactly repay you")
          |> mes("with, you know, actual stuff,")
          |> mes("but I can give you a hot tip.")
          |> mes("There's some guy at the local")
          |> mes("Pub with some precious info.")
          |> next()
          |> mes("[Rochito]")
          |> mes("Yeah, supposedly, this")
          |> mes("guy knows more about the")
          |> mes("cave that Comodo was built")
          |> mes("in... Anyway, I really get the")
          |> mes("feeling that it just might")
          |> mes("lead to something, you know?")
      end

    close(ctx)
  end
end
