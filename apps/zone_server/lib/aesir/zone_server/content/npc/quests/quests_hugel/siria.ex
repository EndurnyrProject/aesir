defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Siria do
  @moduledoc """
  Siria asks the player to help obtain medicine for Morriphen.

  ## Behavior

  - Directs the player to Dono and recovers after receiving medicine.

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
    spawn: [%{map: "hu_in01", x: 326, y: 307, dir: 3, sprite: 90, name: "Siria", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_bio, 0) do
      1 ->
        request_medicine(ctx)

      2 ->
        ctx
        |> mes("[Siria]")
        |> mes("^333333*Sniff*^000000 Please")
        |> mes("go to Lighthalzen and")
        |> mes("get ^333333*Cough*^000000 Morriphen's")
        |> mes("medicine from his friend,")
        |> mes("Dono, as soon as you can.")
        |> close()

      v when v in [3, 4, 5] ->
        ctx
        |> mes("[Siria]")
        |> mes("Oh, have you met Dono?")
        |> mes("I'm so grateful for all of")
        |> mes("his help. He really is a")
        |> mes("good friend to Morriphen,")
        |> mes("no matter what he says.")
        |> close()

      6 ->
        ctx
        |> mes("[Siria]")
        |> mes("*Cough* I-I'm fine,")
        |> mes("so please don't worry")
        |> mes("about me. Just bring the")
        |> mes("medicine to Morriphen as")
        |> mes("fast as you can for me.")
        |> close()

      7 ->
        administer_medicine(ctx)

      8 ->
        ctx
        |> mes("[Siria]")
        |> mes("Oh, please go back")
        |> mes("to Morriphen and let")
        |> mes("him know that I'm much")
        |> mes("better. I don't want him")
        |> mes("to worry about me!")
        |> close()

      9 ->
        ctx
        |> mes("[Siria]")
        |> mes("Oh, welcome~")
        |> mes("Thank you so much")
        |> mes("for helping me and")
        |> mes("Morriphen. You've been")
        |> mes("a real godsend, you know?")
        |> close()

      _ ->
        ctx
        |> mes("[Siria]")
        |> mes("Oh, hello there.")
        |> mes("Can I help you")
        |> mes("with anything?")
        |> close()
    end
  end

  defp request_medicine(ctx) do
    ctx
    |> mes("[Siria]")
    |> mes("Oh, hello there.")
    |> mes("Can I help you")
    |> mes("with anything?")
    |> mes("It looks like you want")
    |> mes("to ask me something...")
    |> next()
    |> mes("^3355FFHow can a woman this")
    |> mes("young be Morriphen's wife?^000000")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Yes, um, Morriphen sent")
    |> mes("me here so that I can bring")
    |> mes("him his medicine. I was wo--")
    |> next()
    |> mes("[Siria]")
    |> mes("Oh my God! Is he alright?")
    |> mes("Please, oh dear Lord, don't")
    |> mes("let him be dead! No! D-did")
    |> mes("anything bad happen to him?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("(She is being panicky, and doesn't seem to know what she should do.")
    |> mes("She absent-mindedly steps forward and then stumbles on the floor.)")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Are you okay?!")
    |> mes("(Her eyes look blank. She seems to have a hard time to see things.)")
    |> next()
    |> mes("[Siria]")
    |> mes("Oh, I am fine, thank you.")
    |> mes("I am just...I am just having a vision problem.")
    |> mes("So...what happened to him?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("He's just not feeling")
    |> mes("well, that's all. All he")
    |> mes("told me was that he ran")
    |> mes("out of his medicine, and")
    |> mes("needs some more.")
    |> next()
    |> mes("[Siria]")
    |> mes("Aww, I just ran out of")
    |> mes("the medicine too. Find")
    |> mes("Morriphen's friend, and get")
    |> mes("it from him. He's supposed to")
    |> mes("be in Lighthalzen, somewhere...")
    |> next()
    |> mes("[Siria]")
    |> mes("^333333*Cough cough!*^000000")
    |> mes("Ugh, excuse me.")
    |> mes("Let me sit down for")
    |> mes("a moment. *Cough!*")
    |> next()
    |> mes("^3355FFSiria's face grows")
    |> mes("pale, and she starts")
    |> mes("to sweat profusely.^000000")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Um...")
    |> mes("Are you feeling")
    |> mes("alright? You're not")
    |> mes("sick too, are you?")
    |> next()
    |> mes("[Siria]")
    |> mes("Oh, no, no... I'm just")
    |> mes("so worried about Morriphen.")
    |> mes("*Sob* I can't live without him,")
    |> mes("he's everything in the world")
    |> mes("to me. I owe him everything,")
    |> mes("I have to go see Dono, I hav--")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("You know what? You better")
    |> mes("relax and rest here, and I'll")
    |> mes("go visit this Dono person in")
    |> mes("Lighthalzen. You don't sound")
    |> mes("well enough to be traveling.")
    |> next()
    |> mes("[Siria]")
    |> mes("I'm... I'm sorry to")
    |> mes("trouble you. But if")
    |> mes("Morriphen can trust you")
    |> mes("to come here, then I'll")
    |> mes("trust you too. ^333333*Cough*^000000")
    |> mes("Thank you so much...")
    |> set_char_var(:hg_bio, 2)
    |> changequest(11009, 11010)
    |> close()
  end

  defp administer_medicine(ctx) do
    ctx
    |> mes("^3355FFYou gently administered")
    |> mes("the medicine to Siria, who")
    |> mes("slow regained consciousness.^000000")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hey, are you alright?")
    |> mes("How are you feeling?")
    |> mes("Morriphen asked me to")
    |> mes("come here and give you")
    |> mes("this medicine right away.")
    |> next()
    |> mes("[Siria]")
    |> mes("...Ah... I can't...")
    |> mes("I don't know... I...")
    |> mes("Where is...? Oh, it's")
    |> mes("you. I think... I think")
    |> mes("you just saved my life.")
    |> mes("I'm sorry for being a burden...")
    |> next()
    |> mes("[Siria]")
    |> mes("All I've been is a nuisance")
    |> mes("to both Morriphen and Dono.")
    |> mes("You don't understand how I've")
    |> mes("destroyed their lives. I just--")
    |> mes("I just... I just need to relax.")
    |> mes("Thank you for everything...")
    |> set_char_var(:hg_bio, 8)
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 30000, else: 500_000), 0)
    |> changequest(11015, 11016)
    |> close()
  end
end
