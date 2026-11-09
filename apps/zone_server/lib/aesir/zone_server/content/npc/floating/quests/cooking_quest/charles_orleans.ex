defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.CookingQuest.CharlesOrleans do
  @moduledoc """
  Charles Orleans teaches a first cooking recipe and lends cookbooks to his apprentices.

  ## Behavior

  - Checks carrying capacity, Novice status, and Chef Hat attire before cooking lessons.
  - Assigns one of six random recipes, trades its ingredients for a finished dish, and
    follows the character's `cooking_q` progression through the kitchen conversations.
  - Offers level 1 through 5 cookbook exchanges for the current cookbook and requested food.
  - Shows the child, cat, Wickebine, and missing-king conversations at their quest stages.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Reddozen
    - L0ne_W0lf
    - Lupus
    - Irmin
    - Samuray22
    - ultramage
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_cas",
        x: 324,
        y: 200,
        dir: 5,
        sprite: 878,
        name: "Charles Orleans",
        scope: :renewal,
        unique_name: "Charles Orleans#cook"
      },
      %{
        map: "prt_castle",
        x: 43,
        y: 30,
        dir: 3,
        sprite: 878,
        name: "Charles Orleans",
        scope: :pre_renewal,
        unique_name: "Charles Orleans#cook"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @child "Child with Cat#cook"
  @wickebine "Wickebine#cook"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 ->
        refuse_overburdened_player(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        greet_novice(ctx, sex(ctx) == 1)

      getequipid(ctx, 6) != 5026 ->
        greet_visitor(ctx, sex(ctx) == 1)

      true ->
        discuss_cooking(ctx, get_char_var(ctx, :cooking_q, 0))
    end
  end

  defp refuse_overburdened_player(ctx) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Just one second.")
    |> mes("You're carrying too")
    |> mes("many items with you")
    |> mes("right now, so you better")
    |> mes("place some of your things")
    |> mes("into Kafra Storage, yes?")
    |> close()
  end

  defp greet_novice(ctx, true) do
    ctx
    |> cutin("orleans_5", 0)
    |> mes("[Charles Orleans]")
    |> mes("Excuse me, monsieur?")
    |> mes("Yes, you. If you're not")
    |> mes("here as hired help for the")
    |> mes("kitchen, then I'd like to")
    |> mes("ask you to leave now.")
    |> next()
    |> emotion(:fret)
    |> mes("[Charles Orleans]")
    |> mes("Please don't be")
    |> mes("offended, but I can't")
    |> mes("concentrate on my ")
    |> mes("cooking when Novices")
    |> mes("like yourself are running")
    |> mes("around here like children.")
    |> close()
    |> cutin("", 255)
  end

  defp greet_novice(ctx, false) do
    ctx
    |> cutin("orleans_1", 0)
    |> mes("[Charles Orleans]")
    |> mes("Mademoiselle, what")
    |> mes("are you doing in this")
    |> mes("area of the castle?")
    |> mes("Oh, you must be lost~")
    |> next()
    |> cutin("orleans_2", 0)
    |> mes("[Charles Orleans]")
    |> mes("Please, use the stairs")
    |> mes("to the right to exit into the")
    |> mes("main structure. My dear,")
    |> mes("be careful and watch your")
    |> mes("step when you climb up")
    |> mes("the stairs for me, alright?")
    |> finish_conversation()
  end

  defp greet_visitor(ctx, true) do
    ctx
    |> cutin("orleans_5", 0)
    |> emotion(:fret)
    |> mes("[Charles Orleans]")
    |> mes("Monsieur, why you look")
    |> mes("at me so? Is it the Morocc")
    |> mes("silk shirt I am wearing, my")
    |> mes("hair styled by Madam Veronica,")
    |> mes("or my brand name muffler")
    |> mes("refined by Monsieur Antonio?")
    |> next()
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Perhaps you are in awe")
    |> mes("of the latest, fashionable")
    |> mes("spectacles that was designed")
    |> mes("by the artists from the Rekenber Corporation? Please, do tell~")
    |> next()
    |> cutin("orleans_2", 0)
    |> mes("[Charles Orleans]")
    |> mes("Wait, wait just a")
    |> mes("moment. Do you know")
    |> mes("anything about the latest")
    |> mes("trends? You don't seem")
    |> mes("to be very fashionable...")
    |> next()
    |> cutin("orleans_5", 0)
    |> cutin("orleans_4", 0)
    |> mes("[Charles Orleans]")
    |> mes("Ugh, if I can avoid it,")
    |> mes("I usually prefer not to")
    |> mes("associate with ruffians.")
    |> mes("But I do find that you")
    |> mes("adventurers do have")
    |> mes("your strong points...")
    |> finish_conversation()
  end

  defp greet_visitor(ctx, false) do
    {ctx, choice} =
      ctx
      |> cutin("orleans_1", 0)
      |> mes("[Charles Orleans]")
      |> mes("Oh! Pardon the squalor")
      |> mes("of my humble kitchen,")
      |> mes("Mademoiselle. But even")
      |> mes("the splendor of the Prontera")
      |> mes("Castle pales to the radiance")
      |> mes("of your captivating beauty.")
      |> next()
      |> cutin("orleans_2", 0)
      |> mes("[Charles Orleans]")
      |> mes("Tell me, who is the")
      |> mes("lovely child holding")
      |> mes("the cat right next to you?")
      |> mes("I know it is rude to ask,")
      |> mes("but I am emboldened by")
      |> mes("my, shall we say, curiosity.")
      |> next()
      |> select(["......?", "She is my sister", "Actually, I don't know her."])

    ctx
    |> discuss_child(choice)
    |> introduce_charles()
  end

  defp discuss_child(ctx, 1) do
    child = getnpcid(ctx, @child)

    ctx
    |> cutin("nyuang_3", 2)
    |> emotion(:delight, child)
    |> mes("[The kid with a cat]")
    |> mes("Nyahahaha,")
    |> mes("Nyahahaha~")
    |> mes("Meow~ Meow~")
    |> next()
    |> cutin("orleans_2", 0)
    |> emotion(:smile)
    |> mes("[Charles Orleans]")
    |> mes("What a lovely child.")
    |> mes("Be quiet like a good girl.")
    |> next()
  end

  defp discuss_child(ctx, 2) do
    child = getnpcid(ctx, @child)

    ctx
    |> cutin("nyuang_1", 2)
    |> emotion(:question, child)
    |> mes("[Child with Cat]")
    |> mes("...Nya?")
    |> mes("...Meow?")
    |> next()
    |> cutin("orleans_2", 0)
    |> emotion(:bigthrob)
    |> mes("[Charles Orleans]")
    |> mes("She is lovely and")
    |> mes("quite although she")
    |> mes("doesn't look like you.")
    |> mes("Even her cat looks adorable.")
  end

  defp discuss_child(ctx, 3) do
    child = getnpcid(ctx, @child)

    ctx
    |> cutin("nyuang_2", 2)
    |> emotion(:hng, child)
    |> mes("[Child with Cat]")
    |> mes("Nyahahaha,")
    |> mes("Nyahahaha~")
    |> mes("Meow, meow~")
    |> next()
    |> cutin("orleans_4", 0)
    |> cutin("orleans_3", 0)
    |> emotion(:profusely_sweat)
    |> mes("[Charles Orleans]")
    |> mes("Ah, again, let me")
    |> mes("apologize. I had believed")
    |> mes("that this child was fortunate")
    |> mes("enough to be a companion")
    |> mes("of the mademoiselle.")
  end

  defp discuss_child(ctx, _choice), do: ctx

  defp introduce_charles(ctx) do
    ctx
    |> next()
    |> cutin("orleans_1", 0)
    |> mes("[Charles Orleans]")
    |> mes("Allow me to introduce")
    |> mes("myself to you, amour.")
    |> mes("I am your ever faithful")
    |> mes("servant whose heart is")
    |> mes("enraptured by your gaze.")
    |> mes("My name is Charles Orleans.")
    |> next()
    |> cutin("orleans_4", 0)
    |> mes("[Charles Orleans]")
    |> mes("Yet there is one thing that")
    |> mes("anguishes me. Ever since his")
    |> mes("highness, King Tristram III,")
    |> mes("has vanished, I have found no")
    |> mes("one worthy of tasting my wares.")
    |> mes("My life now lacks meaning...")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Alas, recently I have been")
    |> mes("reduced to teaching mere")
    |> mes("apprentices, tyros in the")
    |> mes("culinary arts, my skills.")
    |> mes("It is frustrating--many of")
    |> mes("them do not have any talent!")
    |> next()
    |> cutin("orleans_3", 0)
    |> mes("[Charles Orleans]")
    |> mes("Ah, forgive me, dear")
    |> mes("Mademoiselle. I hope you")
    |> mes("understand the difficulty")
    |> mes("I am forced to suffer. When")
    |> mes("next we meet, I would very much like to give you a sweet dessert.")
    |> next()
    |> cutin("orleans_1", 0)
    |> mes("[Charles Orleans]")
    |> mes("Yes, women with your")
    |> mes("beauty definitely deserve")
    |> mes("the luscious flavors of the")
    |> mes("treats that only I can offer.")
    |> mes("Until that day comes, I shall")
    |> mes("reluctantly bid you adieu.")
    |> finish_conversation()
  end

  defp discuss_cooking(ctx, 0) do
    {ctx, choice} =
      ctx
      |> cutin("orleans_5", 0)
      |> emotion(:think)
      |> mes("[Charles Orleans]")
      |> mes("Oh, have you come here")
      |> mes("to learn cooking? ^333333*Sigh*^000000")
      |> mes("I don't feel like teaching")
      |> mes("anything today--in fact,")
      |> mes("I think teaching is a waste")
      |> mes("of my time! ^333333*Sigh*^000000 However...")
      |> next()
      |> select(["Um, are you talking to me?", "Wait, don't you remember me?", "Sir Orleans?"])

    ctx =
      ctx
      |> respond_to_apprentice(choice)
      |> next()
      |> cutin("orleans_7", 0)
      |> mes("[Charles Orleans]")
      |> mes("Well then, let's get started")
      |> mes("today with making a simple")
      |> mes("dish. Okay, ^FF0000I don't teach recipes")
      |> mes("more than once^000000, ^FF0000so make sure")
      |> mes("that you write this down^000000. Now")
      |> mes("then, what shall we cook?")
      |> next()
      |> cutin("orleans_6", 0)
      |> set_local(:cook_m1, Enum.random(1..6))

    assign_recipe(ctx, get_local(ctx, :cook_m1, 0))
  end

  defp discuss_cooking(ctx, recipe) when recipe in 1..6 do
    if has_ingredients?(ctx, recipe) do
      teach_recipe(ctx, recipe)
    else
      remind_ingredients(ctx, recipe)
    end
  end

  defp discuss_cooking(ctx, 7) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Oh... I'm so exhausted!")
    |> mes("I have too much wisdom and")
    |> mes("skills to pass on! Teaching is")
    |> mes("not an endeavor I enjoy, but")
    |> mes("I do realize it is necessary")
    |> mes("for my cuisine to survive me...")
    |> next()
    |> cutin("orleans_1", 0)
    |> mes("[Charles Orleans]")
    |> mes("Peser le bien et le mal...")
    |> mes("Even though it pains me,")
    |> mes("I suppose I have to continue")
    |> mes("teaching until one of you can")
    |> mes("become a worthy successor.")
    |> mes("It will take some time...")
    |> finish_conversation()
  end

  defp discuss_cooking(ctx, 8) do
    {ctx, choice} =
      ctx
      |> cutin("orleans_5", 0)
      |> mes("[Charles Orleans]")
      |> mes("Strange, strange...")
      |> mes("What is that kid and")
      |> mes("that cat doing here?")
      |> mes("The kitchen is no place")
      |> mes("for them--at the very least,")
      |> mes("not for pets, you know.")
      |> next()
      |> cutin("orleans_4", 0)
      |> mes("[Charles Orleans]")
      |> mes("Pardon moi, child,")
      |> mes("but would you remove")
      |> mes("yourself and your cat")
      |> mes("from the premises? This")
      |> mes("is a kitchen, and everything")
      |> mes("here needs to be clean!")
      |> next()
      |> cutin("nyuang_1", 2)
      |> mes("[Child with Cat]")
      |> mes("...Nyaaa?")
      |> mes("...Meow?")
      |> next()
      |> select([
        "What's your name, kid?",
        "Do you want to eat something?",
        "Here, kitty~",
        "Get out!"
      ])

    respond_to_child(ctx, choice)
  end

  defp discuss_cooking(ctx, 9) do
    ctx
    |> ask_child_to_leave()
    |> welcome_wickebine()
    |> reassure_wickebine()
    |> part_with_wickebine()
  end

  defp discuss_cooking(ctx, 10) do
    ctx
    |> cutin("orleans_5", 0)
    |> mes("[Charles Orleans]")
    |> mes("It's been bothering")
    |> mes("me that his highness")
    |> mes("has been missing for")
    |> mes("a while. Why doesn't")
    |> mes("anybody know where he is?")
    |> next()
    |> cutin("orleans_4", 0)
    |> cutin("orleans_3", 0)
    |> mes("[Charles Orleans]")
    |> mes("Wise and benevolent")
    |> mes("King Tristram III would")
    |> mes("never abandon his subjects.")
    |> mes("I dearly hope that nothing")
    |> mes("serious has happened to him...")
    |> next()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Can it be possible that")
    |> mes("our beloved king would")
    |> mes("have enemies? He's done")
    |> mes("nothing but good for the")
    |> mes("Rune-Midgarts Kingdom")
    |> mes("and the rest of the world!")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("I can't imagine a great")
    |> mes("man like him to be in any")
    |> mes("sort of trouble. It makes me")
    |> mes("me laugh whenever anyone")
    |> mes("suggests that he is hiding")
    |> mes("in the Schwarzwald Republic...")
    |> next()
    |> emotion(:go)
    |> mes("[Charles Orleans]")
    |> mes("Praise the glories of the")
    |> mes("Rune-Midgarts Kingdom!")
    |> mes("Long live King Tristram III!")
    |> finish_conversation()
  end

  defp discuss_cooking(ctx, 11) do
    {ctx, choice} =
      ctx
      |> cutin("orleans_5", 0)
      |> emotion(:think)
      |> mes("[Charles Orleans]")
      |> mes("Oh, I'm in great need of")
      |> mes("some rest. Unless you ")
      |> mes("have something incredibly")
      |> mes("important to ask of me,")
      |> mes("please let me take a break~")
      |> next()
      |> select([
        "I want to learn more recipes.",
        "For whom do you cook?",
        "I'm sorry to bother you..."
      ])

    case choice do
      1 -> borrow_cookbook(ctx)
      2 -> explain_inspiration(ctx)
      3 -> rest_from_teaching(ctx)
      _ -> finish_conversation(ctx)
    end
  end

  defp discuss_cooking(ctx, _stage) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Mon dieu!")
    |> mes("An error has")
    |> mes("occurred!")
    |> finish_conversation()
  end

  defp ask_child_to_leave(ctx) do
    child = getnpcid(ctx, @child)

    ctx
    |> cutin("orleans_5", 0)
    |> emotion(:fret)
    |> mes("[Charles Orleans]")
    |> mes("Alright, enough")
    |> mes("is enough. We can't")
    |> mes("continue to cook if we")
    |> mes("have live animals in the")
    |> mes("kitchen. It's a violation")
    |> mes("of our sanitary standards!")
    |> next()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("I'm sorry, mon chere,")
    |> mes("but you have to leave.")
    |> mes("Child, please take your")
    |> mes("cat and head out the door")
    |> mes("before your feline can touch")
    |> mes("or shed on any of the food!")
    |> next()
    |> cutin("nyuang_4", 2)
    |> emotion(:fret, child)
    |> mes("[Child with Cat]")
    |> mes("Grrrrrrr!")
    |> mes("RRRRreow!")
    |> next()
  end

  defp welcome_wickebine(ctx) do
    child = getnpcid(ctx, @child)

    ctx
    |> donpcevent("Wickebine#cook::OnEnable")
    |> emotion(:huk)
    |> emotion(:delight, child)
    |> next()
    |> cutin("job_black_hucke01", 1)
    |> mes("[Wickebine]")
    |> mes("Oh...!")
    |> mes("Nyuyang, there")
    |> mes("you are! What are")
    |> mes("you doing here in")
    |> mes("Charles's kitchen?")
    |> next()
    |> cutin("orleans_3", 0)
    |> mes("[Charles Orleans]")
    |> mes("M-Madam Wickebine...!")
    |> mes("Forgive me, you surprised")
    |> mes("me by appearing from out")
    |> mes("of nowhere. Do you happen")
    |> mes("to know this young child?")
    |> next()
    |> cutin("job_black_hucke02", 1)
    |> mes("[Wickebine]")
    |> mes("Oh, Nyuyang here is my")
    |> mes("little sister. It may be hard")
    |> mes("to see the resemblance...")
    |> mes("Anyway, I've been looking")
    |> mes("all over for her. Are you")
    |> mes("bothering Charles, Nyuyang?")
    |> next()
  end

  defp reassure_wickebine(ctx) do
    child = getnpcid(ctx, @child)

    ctx
    |> cutin("nyuang_3", 2)
    |> emotion(:smile, child)
    |> mes("[Child with Cat]")
    |> mes("Nyuuuunyuuu~")
    |> mes("nyuuuunyuuu~")
    |> mes("Meooooow~")
    |> next()
    |> cutin("orleans_3", 0)
    |> mes("[Charles Orleans]")
    |> mes("...!!!")
    |> next()
    |> cutin("job_black_hucke03", 1)
    |> mes("[Wickebine]")
    |> mes("Oh, so you have")
    |> mes("been bothering him!")
    |> mes("You think Charles")
    |> mes("wants you to leave?")
    |> next()
    |> cutin("orleans_3", 0)
    |> emotion(:profusely_sweat)
    |> mes("[Charles Orleans]")
    |> mes("Hahahahah, what")
    |> mes("are you talking about!")
    |> mes("Nonsense! How can ")
    |> mes("such a cute little belle")
    |> mes("be of any trouble to me?")
    |> next()
  end

  defp part_with_wickebine(ctx) do
    child = getnpcid(ctx, @child)
    wickebine = getnpcid(ctx, @wickebine)

    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("As a matter of fact,")
    |> mes("I was just about to treat")
    |> mes("this precious petit and")
    |> mes("her little cat to some")
    |> mes("of my delicious cuisine.")
    |> mes("So do not worry, Madam~")
    |> next()
    |> cutin("job_black_hucke01", 1)
    |> emotion(:question, wickebine)
    |> mes("[Wickebine]")
    |> mes("Are you sure, Charles?")
    |> mes("I know how serious you")
    |> mes("are about your cooking,")
    |> mes("and I don't want Nyuyang")
    |> mes("to disturb you in any way...")
    |> next()
    |> cutin("job_black_hucke02", 1)
    |> mes("[Wickebine]")
    |> mes("Oh, Charles, you've")
    |> mes("been nothing but kind")
    |> mes("to me. I'm glad that you're")
    |> mes("also taking care of Nyuyang.")
    |> mes("Well then, take care~")
    |> next()
    |> cutin("nyuang_3", 2)
    |> emotion(:smile, child)
    |> mes("[Child with Cat]")
    |> mes("Nyahahaha~")
    |> mes("Nyahahaha~")
    |> mes("(Meow, meow~)")
    |> next()
    |> cutin("job_black_hucke02", 255)
    |> emotion(:delight, wickebine)
    |> donpcevent("Wickebine#cook::OnDisable")
    |> next()
    |> emotion(:think)
    |> emotion(:think, child)
    |> mes("[Charles Orleans]")
    |> mes("......")
    |> next()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Ah...")
    |> mes("There goes a true")
    |> mes("lady... Madam Wickebine...")
    |> finish_conversation()
  end

  defp respond_to_apprentice(ctx, 1) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Who else would")
    |> mes("I be talking to?")
    |> mes("To Madeleine over")
    |> mes("there? Or that child")
    |> mes("holding that mangy")
    |> mes("cat? Sacrebleu!")
    |> next()
    |> cutin("nyuang_4", 2)
    |> mes("[Child with Cat]")
    |> mes("Grrrrrrr!")
    |> mes("Rrrroreow!")
    |> next()
    |> cutin("orleans_4", 0)
    |> cutin("orleans_3", 0)
    |> emotion(:huk)
    |> mes("[Charles Orleans]")
    |> mes("Goodness, you scared me!")
    |> mes("What an ill natured kid!")
    |> mes("Who brought this kid in?")
  end

  defp respond_to_apprentice(ctx, 2) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("I can't remember every")
    |> mes("tyro who's begged me for")
    |> mes("instruction in the culinary")
    |> mes("arts. I could swear you've")
    |> mes("come here months ago, it's")
    |> mes("just--what was your name...?")
    |> next()
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Bah! No matter.")
    |> mes("I suppose that's")
    |> mes("of no importance")
    |> mes("at the moment.")
  end

  defp respond_to_apprentice(ctx, 3) do
    ctx
    |> cutin("orleans_4", 0)
    |> mes("[Charles Orleans]")
    |> mes("E-excuse me? I may be")
    |> mes("your instructor, but you")
    |> mes("can call me by my first name.")
    |> mes("I know that I can be strict,")
    |> mes("but please: in the end, we are colleagues, even if I am superior.")
    |> next()
    |> cutin("orleans_1", 0)
    |> mes("[Charles Orleans]")
    |> mes("Fine, fine...")
    |> mes("If you insist on your")
    |> mes("modicum of expressed")
    |> mes("respect, then you may")
    |> mes("call me ''Sir Charles.''")
    |> next()
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Ah... That does have")
    |> mes("a rather fine ring to it.")
    |> mes("I actually earned that title")
    |> mes("from the king himself, even")
    |> mes("if I'm a knight only in title and manner, rather than strength.")
  end

  defp respond_to_apprentice(ctx, _choice), do: ctx

  defp assign_recipe(ctx, 1) do
    ctx
    |> set_char_var(:cooking_q, 1)
    |> mes("[Charles Orleans]")
    |> mes("Ahhh, how about")
    |> mes("'Fried Grasshopper Legs?'")
    |> mes("To the uninitiated, it may")
    |> mes("seem to be a disgusting dish,")
    |> mes("but trust me, its exquisite taste is pure pleasure for your palate.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Now, please bring")
    |> mes("^4D4DFF5 Grasshopper Legs^000000,")
    |> mes("^4D4DFF1 Cooking Oil^000000, and")
    |> mes("^4D4DFF1 Old Frying Pan^000000.")
    |> mes("Then, we can begin.")
    |> finish_conversation()
  end

  defp assign_recipe(ctx, 2) do
    ctx
    |> set_char_var(:cooking_q, 2)
    |> mes("[Charles Orleans]")
    |> mes("Ah, I've got it!")
    |> mes("Let's make ''Grape Juice")
    |> mes("Herbal Tea.'' The weather")
    |> mes("is perfect right now for")
    |> mes("a cool, refreshing drink.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Please bring")
    |> mes("^4D4DFF3 Grapes^000000, and")
    |> mes("^4D4DFF2 Red Potions^000000")
    |> mes("so that we can")
    |> mes("begin the lesson~")
    |> finish_conversation()
  end

  defp assign_recipe(ctx, 3) do
    ctx
    |> set_char_var(:cooking_q, 3)
    |> mes("[Charles Orleans]")
    |> mes("I've got it~")
    |> mes("We can make")
    |> mes("''Honey Grape Juice.''")
    |> mes("Please bring me the")
    |> mes("following ingredients so")
    |> mes("that we can begin the lesson.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("^4D4DFF1 Honey^000000,")
    |> mes("^4D4DFF2 Grapes^000000, and")
    |> mes("^4D4DFF1 Red Potion^000000.")
    |> finish_conversation()
  end

  defp assign_recipe(ctx, 4) do
    ctx
    |> set_char_var(:cooking_q, 4)
    |> mes("[Charles Orleans]")
    |> mes("Mmm, why don't we")
    |> mes("make ''Frog Egg and")
    |> mes("Squid Ink Soup?'' Those")
    |> mes("bereft of gourmet taste may")
    |> mes("think it's disgusting, but it's")
    |> mes("actually quite scrumptious.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Well then,")
    |> mes("please bring me")
    |> mes("^4D4DFF1 Bag of Grain^000000,")
    |> mes("^4D4DFF10 Spawns^000000, and")
    |> mes("^4D4DFF1 Squid Ink^000000.")
    |> finish_conversation()
  end

  defp assign_recipe(ctx, 5) do
    ctx
    |> set_char_var(:cooking_q, 5)
    |> mes("[Charles Orleans]")
    |> mes("Ah, I know what")
    |> mes("would be perfect right")
    |> mes("now. ''Steamed Crab")
    |> mes("Nippers.'' Now, please")
    |> mes("bring these ingredients")
    |> mes("so we can make this soup.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("We'll need")
    |> mes("^4D4DFF10 Green Herbs^000000,")
    |> mes("^4D4DFF10 Nippers^000000, and")
    |> mes("^4D4DFF1 Yellow Potion^000000.")
    |> finish_conversation()
  end

  defp assign_recipe(ctx, _recipe) do
    ctx
    |> set_char_var(:cooking_q, 6)
    |> mes("[Charles Orleans]")
    |> mes("Ooh, you know what")
    |> mes("would be scrumptious?")
    |> mes("''Fried Monkey Tails.'' Yes,")
    |> mes("that sounds perfect! Please")
    |> mes("bring these ingredients so")
    |> mes("that I can teach you this dish.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("We'll need")
    |> mes("^4D4DFF1 Frying Pan^000000,")
    |> mes("^4D4DFF5 Yoyo Tails^000000, and")
    |> mes("^4D4DFF1 Cooking Oil^000000.")
    |> finish_conversation()
  end

  defp has_ingredients?(ctx, 1) do
    count_item(ctx, 940) > 4 and count_item(ctx, 7031) > 0 and count_item(ctx, 7457) > 0
  end

  defp has_ingredients?(ctx, 2) do
    count_item(ctx, 514) > 2 and count_item(ctx, 501) > 1
  end

  defp has_ingredients?(ctx, 3) do
    count_item(ctx, 518) > 0 and count_item(ctx, 514) > 1 and count_item(ctx, 501) > 0
  end

  defp has_ingredients?(ctx, 4) do
    count_item(ctx, 577) > 0 and count_item(ctx, 908) > 9 and count_item(ctx, 1024) > 0
  end

  defp has_ingredients?(ctx, 5) do
    count_item(ctx, 960) > 9 and count_item(ctx, 511) > 9 and count_item(ctx, 503) > 0
  end

  defp has_ingredients?(ctx, 6) do
    count_item(ctx, 942) > 4 and count_item(ctx, 7031) > 0 and count_item(ctx, 7457) > 0
  end

  defp introduce_lesson(ctx) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Finally, you're here! Never")
    |> mes("forget: your ingredients must")
    |> mes("always be as fresh as possible.")
    |> mes("If not, your cuisine will be much poorer in quality. Now, let me")
    |> mes("explain how to make this dish.")
    |> next()
  end

  defp conclude_lesson(ctx) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("There, you're done!")
    |> mes("The presentation can use")
    |> mes("a little work, but at least you")
    |> mes("know this recipe now. That's")
    |> mes("all for today, so please go")
    |> mes("and practice on your own now.")
  end

  defp teach_recipe(ctx, 1) do
    ctx
    |> cutin("orleans_4", 0)
    |> emotion(:fret)
    |> introduce_lesson()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Scrub the Grasshopper Legs")
    |> mes("as cleanly as you can before")
    |> mes("placing them in the Frying Pan.")
    |> mes("Afterwards, pour half a bottle of Cooking Oil and fry the legs at")
    |> mes("high heat for about 20 minutes.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Now, follow the instructions")
    |> mes("that I've just given you to the")
    |> mes("letter! Hmmm... Good, good.")
    |> mes("That's not bad at all. Alright,")
    |> mes("you're almost there...")
    |> next()
    |> conclude_lesson()
    |> delitem(940, 5)
    |> delitem(7031, 1)
    |> delitem(7457, 1)
    |> set_char_var(:cooking_q, 7)
    |> give_item(12_041, 1)
    |> finish_conversation()
  end

  defp teach_recipe(ctx, 2) do
    ctx
    |> cutin("orleans_4", 0)
    |> introduce_lesson()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("You extract the juice")
    |> mes("from the Grapes like this--")
    |> mes("we can't use pre-made Grape")
    |> mes("Juice for the sake of freshness. Then, you need to boil the Red")
    |> mes("Potions in a bain-marie...")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("When the Red Potions")
    |> mes("reach the right consistency,")
    |> mes("gently stir in the juice that you just squeezed from the Grapes.")
    |> mes("Now, I want you to try it. Hmm... That's not bad... Good, good...")
    |> next()
    |> conclude_lesson()
    |> delitem(514, 3)
    |> delitem(501, 2)
    |> set_char_var(:cooking_q, 7)
    |> give_item(12_046, 1)
    |> finish_conversation()
  end

  defp teach_recipe(ctx, 3) do
    ctx
    |> cutin("orleans_4", 0)
    |> introduce_lesson()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("First, skin the Grapes")
    |> mes("and extract the seeds. Then,")
    |> mes("blend the Grapes with the")
    |> mes("Honey. Take this blended")
    |> mes("mixture and carefully stir")
    |> mes("it into the Red Potion...")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("When the pulp is fully")
    |> mes("mixed into the Red Potion,")
    |> mes("you'll be finished. Now, go")
    |> mes("and try making it yourself.")
    |> mes("Right, that's good. Yes...")
    |> mes("Wait, wait! Okay, there you go~")
    |> next()
    |> conclude_lesson()
    |> delitem(518, 1)
    |> delitem(514, 2)
    |> delitem(501, 1)
    |> set_char_var(:cooking_q, 7)
    |> give_item(12_061, 1)
    |> finish_conversation()
  end

  defp teach_recipe(ctx, 4) do
    ctx
    |> cutin("orleans_4", 0)
    |> introduce_lesson()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Mill the grain until")
    |> mes("it's a fine flour, then")
    |> mes("boil the Squid Ink at")
    |> mes("medium heat. Once it")
    |> mes("bubbles, pour in the flour.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Keep stirring, slowly")
    |> mes("adding the Spawns. When")
    |> mes("it all boils again, reduce the")
    |> mes("heat and simmer for about 10")
    |> mes("minutes. Okay, now you try it.")
    |> mes("That's good, good... Alright~")
    |> next()
    |> conclude_lesson()
    |> delitem(577, 1)
    |> delitem(908, 10)
    |> delitem(1024, 1)
    |> set_char_var(:cooking_q, 7)
    |> give_item(12_056, 1)
    |> finish_conversation()
  end

  defp teach_recipe(ctx, 5) do
    ctx
    |> cutin("orleans_4", 0)
    |> introduce_lesson()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Boil the Nippers in Yellow")
    |> mes("Potion on low heat for about")
    |> mes("30 minutes. Then, bring it down")
    |> mes("to a simmer and carefully stir")
    |> mes("in the Green Herbs one by one.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("This is an easy recipe, but")
    |> mes("I still want you to demonstrate")
    |> mes("for me. Okay, let's see now...")
    |> mes("You're doing fine. Now, wait...")
    |> mes("Good, good, okay, it's ready")
    |> mes("for the Green Herbs now...")
    |> next()
    |> conclude_lesson()
    |> delitem(960, 10)
    |> delitem(511, 10)
    |> delitem(503, 1)
    |> set_char_var(:cooking_q, 7)
    |> give_item(12_051, 1)
    |> finish_conversation()
  end

  defp teach_recipe(ctx, 6) do
    ctx
    |> cutin("orleans_4", 0)
    |> introduce_lesson()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Pluck the hair from the")
    |> mes("tails and rinse them well")
    |> mes("under cold water. Pour half")
    |> mes("a bottle of Cooking Oil unto")
    |> mes("a preheated pan, and then")
    |> mes("quickly fry the tails.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("The trick is to fry the")
    |> mes("tails quickly without burning")
    |> mes("them, so you'll probably want")
    |> mes("to cook using medium-high heat.")
    |> mes("Show me what you've learned now... Alright, that's not bad... Hmmm...")
    |> next()
    |> conclude_lesson()
    |> delitem(942, 5)
    |> delitem(7031, 1)
    |> delitem(7457, 1)
    |> set_char_var(:cooking_q, 7)
    |> give_item(12_066, 1)
    |> finish_conversation()
  end

  defp remind_ingredients(ctx, recipe) do
    ctx =
      ctx
      |> cutin("orleans_6", 0)
      |> set_local(:talk_j, Enum.random(1..2))

    if get_local(ctx, :talk_j, 0) == 1 do
      urge_ingredient_collection(ctx, recipe)
    else
      suggest_ingredient_source(ctx, recipe)
    end
  end

  defp urge_ingredient_collection(ctx, 1) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Hurry and bring me")
    |> mes("the ingredients to make")
    |> mes("Fried Grasshopper Legs!")
    |> mes("If a restaurant patron had")
    |> mes("ordered this, then you'd")
    |> mes("already be making him wait!")
    |> finish_conversation()
  end

  defp urge_ingredient_collection(ctx, 2) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("What are you doing?")
    |> mes("Hurry and bring me the")
    |> mes("ingredients for Grape Juice")
    |> mes("Herbal Tea! At a real restaurant, you'd never be able to take your")
    |> mes("time like this! Quickly, now!")
    |> finish_conversation()
  end

  defp urge_ingredient_collection(ctx, 3) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("What's taking you so")
    |> mes("long? You should have")
    |> mes("brought me the ingredients")
    |> mes("to make Honey Grape Juice")
    |> mes("a while ago. Hurry it up!")
    |> finish_conversation()
  end

  defp urge_ingredient_collection(ctx, 4) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("What are you doing?")
    |> mes("You're supposed to be")
    |> mes("preparing ingredients")
    |> mes("for Frog Egg and Squid")
    |> mes("Ink Soup right now!")
    |> finish_conversation()
  end

  defp urge_ingredient_collection(ctx, 5) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Shouldn't you be")
    |> mes("preparing all of the")
    |> mes("ingredients for Steamed")
    |> mes("Crab Nippers? You need")
    |> mes("to work quickly for those")
    |> mes("hungry restaurant patrons!")
    |> finish_conversation()
  end

  defp urge_ingredient_collection(ctx, 6) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("You better go prepare")
    |> mes("those ingredients for Fried")
    |> mes("Monkey Tails are quickly as")
    |> mes("you can. In a real restaurant,")
    |> mes("you'd never able to take your")
    |> mes("time like this. Toute allure!")
    |> finish_conversation()
  end

  defp suggest_ingredient_source(ctx, 1) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Just go and ambush those")
    |> mes("happy-go-lucky grasshoppers")
    |> mes("just playing in the fields. Hurry and smash them, then rip their")
    |> mes("legs off--but be humane about it! ")
    |> finish_conversation()
  end

  defp suggest_ingredient_source(ctx, 2) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Having trouble finding")
    |> mes("Grapes? Just pop open")
    |> mes("those cute little Poporings...")
    |> mes("Of course, you should try to")
    |> mes("be humane when you hunt them...")
    |> finish_conversation()
  end

  defp suggest_ingredient_source(ctx, 3) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("You're having trouble")
    |> mes("finding some Honey for the")
    |> mes("Honey Grape Juice, aren't you?")
    |> mes("Just go and hunt some bears,")
    |> mes("they're always carrying some")
    |> mes("of that Honey around.")
    |> finish_conversation()
  end

  defp suggest_ingredient_source(ctx, 4) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("You have to be careful")
    |> mes("when you're handling Frog")
    |> mes("Eggs. If you feed them raw to")
    |> mes("somebody, well, their flavor is")
    |> mes("decidely less than magnifique.")
    |> finish_conversation()
  end

  defp suggest_ingredient_source(ctx, 5) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("It shouldn't be too hard")
    |> mes("to gather Nippers. Just")
    |> mes("find some Vadons and crush")
    |> mes("them, making sure to rip off")
    |> mes("their Nippers. That sounds strange, I know, but just do it.")
    |> finish_conversation()
  end

  defp suggest_ingredient_source(ctx, 6) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("You need more tails?")
    |> mes("Just sneak up on some")
    |> mes("Yoyos, swiftly kill them,")
    |> mes("and then slice off their tails.")
    |> mes("You're a beginner, but I won't")
    |> mes("allow you to be inhumane!")
    |> finish_conversation()
  end

  defp respond_to_child(ctx, 1) do
    child = getnpcid(ctx, @child)

    ctx
    |> emotion(:ok, child)
    |> mes("[Child with Cat]")
    |> mes("Nyaaa~")
    |> mes("nyaaa~")
    |> mes("(Purrrrrr)")
    |> next()
    |> cutin("orleans_4", 0)
    |> mes("[Charles Orleans]")
    |> mes(".....Who told you")
    |> mes("to ask her name?")
    |> mes("You don't even understand what she is saying.")
    |> finish_conversation()
  end

  defp respond_to_child(ctx, 2) do
    child = getnpcid(ctx, @child)

    ctx
    |> cutin("nyuang_2", 2)
    |> emotion(:hng, child)
    |> mes("[Child with Cat]")
    |> mes("Nyaaaa~")
    |> mes("(Purrrrrr~)")
    |> next()
    |> cutin("orleans_5", 0)
    |> mes("[Charles Orleans]")
    |> mes("That was a good idea...")
    |> mes("Offering them food to get")
    |> mes("them to leave. Mon dieu, if")
    |> mes("the child won't talk to us...")
    |> mes("Still, we need to get those")
    |> mes("two out of the kitchen.")
    |> finish_conversation()
  end

  defp respond_to_child(ctx, 3) do
    child = getnpcid(ctx, @child)

    ctx
    |> cutin("nyuang_3", 2)
    |> emotion(:smile, child)
    |> mes("[Child with Cat]")
    |> mes("Nyahahaha~")
    |> mes("Nyhhahaha~")
    |> mes("(Meow, meow~)")
    |> next()
    |> cutin("orleans_4", 0)
    |> mes("[Charles Orleans]")
    |> mes("...Are you playing with that kid...?")
    |> mes("...Then I don't need you to be here.")
    |> finish_conversation()
  end

  defp respond_to_child(ctx, 4) do
    child = getnpcid(ctx, @child)

    ctx
    |> emotion(:think, child)
    |> mes("[Child with Cat]")
    |> mes("...")
    |> mes("(Meow?)")
    |> next()
    |> cutin("nyuang_4", 2)
    |> emotion(:fret, child)
    |> specialeffect2(:hit2)
    |> percent_heal(hp: -10, sp: 0)
    |> mes("[Child with Cat]")
    |> mes("Grrrrrrr!")
    |> mes("(RRRrrreow!)")
    |> next()
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Oh, look out!")
    |> mes("You should have")
    |> mes("been more careful")
    |> mes("handling that cat...")
    |> finish_conversation()
  end

  defp respond_to_child(ctx, _choice), do: finish_conversation(ctx)

  defp borrow_cookbook(ctx) do
    {ctx, cookbook_level} =
      ctx
      |> cutin("orleans_7", 0)
      |> mes("[Charles Orleans]")
      |> mes("You want to learn more")
      |> mes("recipes? I suppose that")
      |> mes("you should borrow another")
      |> mes("cookbook then. Before that,")
      |> mes("please return the cookbook")
      |> mes("that you were studying, okay?")
      |> next()
      |> mes("[Charles Orleans]")
      |> mes("Now, choose the cookbook")
      |> mes("that you want to borrow by")
      |> mes("entering a level from 1 to 5.")
      |> mes("There are more advanced books,")
      |> mes("but I'm not lending those out.")
      |> mes("Oh, and enter 0 to cancel.")
      |> next()
      |> input(:int)

    ctx
    |> set_local(:new_book, cookbook_level)
    |> validate_requested_cookbook()
  end

  defp validate_requested_cookbook(ctx) do
    cookbook_level = get_local(ctx, :new_book, 0)

    cond do
      cookbook_level < 0 or cookbook_level > 5 -> invalid_requested_cookbook(ctx)
      cookbook_level == 0 -> cancel_cookbook_exchange(ctx)
      true -> ask_current_cookbook(ctx)
    end
  end

  defp invalid_requested_cookbook(ctx) do
    ctx
    |> cutin("orleans_5", 0)
    |> mes("[Charles Orleans]")
    |> mes("Hmm...")
    |> mes("I asked to you to")
    |> mes("enter a level from")
    |> mes("1 to 5. Those are the")
    |> mes("only cookbooks that I will")
    |> mes("lend out to my students.")
    |> finish_conversation()
  end

  defp cancel_cookbook_exchange(ctx) do
    ctx
    |> cutin("orleans_5", 0)
    |> mes("[Charles Orleans]")
    |> mes("So you changed your mind?")
    |> mes("It would be a good idea to")
    |> mes("study the recipes that you")
    |> mes("have right now before trying")
    |> mes("something new, I suppose.")
    |> finish_conversation()
  end

  defp ask_current_cookbook(ctx) do
    {ctx, cookbook_level} =
      ctx
      |> mes("[Charles Orleans]")
      |> mes("So you wanted to borrow a")
      |> mes("Level #{get_local(ctx, :new_book, 0)} Cookbook, eh?")
      |> mes("Oh, would you please tell")
      |> mes("me the level of the cookbook")
      |> mes("that you are returning to me?")
      |> next()
      |> input(:int)

    ctx
    |> set_local(:old_book, cookbook_level)
    |> validate_current_cookbook()
  end

  defp validate_current_cookbook(ctx) do
    old_book = get_local(ctx, :old_book, 0)
    new_book = get_local(ctx, :new_book, 0)

    cond do
      old_book < 0 or old_book > 5 -> invalid_current_cookbook(ctx)
      old_book == 0 -> cancel_cookbook_exchange(ctx)
      old_book == new_book -> refuse_same_cookbook(ctx)
      count_item(ctx, 7471 + old_book) < 1 -> require_current_cookbook(ctx)
      true -> offer_cookbook_exchange(ctx, old_book, new_book)
    end
  end

  defp invalid_current_cookbook(ctx) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("There must be some")
    |> mes("kind of mistake-- I only")
    |> mes("lend out cookbooks from")
    |> mes("levels 1 to 5. Hmm, well, ask")
    |> mes("me again when you remember")
    |> mes("which cookbook you have, okay?")
    |> finish_conversation()
  end

  defp refuse_same_cookbook(ctx) do
    ctx
    |> cutin("orleans_4", 0)
    |> mes("[Charles Orleans]")
    |> mes("Wait, wait...")
    |> mes("Why do you want to")
    |> mes("borrow a copy of the")
    |> mes("cookbook that you already")
    |> mes("have? I guess you made")
    |> mes("some sort of mistake?")
    |> finish_conversation()
  end

  defp require_current_cookbook(ctx) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Wait, wait...")
    |> mes("Why don't you have")
    |> mes("the book that you said")
    |> mes("that you'd return to me?")
    |> mes("Find it first, and then I can")
    |> mes("lend another cookbook to you.")
    |> finish_conversation()
  end

  defp offer_cookbook_exchange(ctx, old_book, new_book) do
    ctx
    |> cutin("orleans_2", 0)
    |> mes("[Charles Orleans]")
    |> acknowledge_cookbook(old_book)
    |> next()
    |> explain_borrowing_condition()
    |> describe_cookbook_fee(new_book)
    |> confirm_cookbook_fee(new_book)
  end

  defp acknowledge_cookbook(ctx, 1) do
    ctx
    |> mes("Ah, so you're done")
    |> mes("with the Level 1 Cookbook.")
    |> mes("That's good, that means you're")
    |> mes("ready to graduate from the most")
    |> mes("basic of basics. From now on,")
    |> mes("the recipes will be harder...")
  end

  defp acknowledge_cookbook(ctx, 2) do
    ctx
    |> mes("Ah, so what did you")
    |> mes("think of the recipes in")
    |> mes("the Level 2 Cookbook?")
    |> mes("Homestyle cooking may be")
    |> mes("simple, but it should never")
    |> mes("be neglected by chefs.")
  end

  defp acknowledge_cookbook(ctx, 3) do
    ctx
    |> mes("Ah, done with the Level 3")
    |> mes("Cookbook already? The recipes")
    |> mes("in there are really good when you're cooking romantic dinners.")
    |> mes("They'll come in handy someday,")
    |> mes("if you know what I mean.")
  end

  defp acknowledge_cookbook(ctx, 4) do
    ctx
    |> mes("So you've finished the")
    |> mes("Level 4 Cookbook. That's")
    |> mes("no small feat! You've got to")
    |> mes("use very strange ingredients")
    |> mes("to create delicious cuisine!")
  end

  defp acknowledge_cookbook(ctx, 5) do
    ctx
    |> mes("You're done with the")
    |> mes("Level 5 Cookbook? Good")
    |> mes("work: most beginners don't")
    |> mes("even get this far. I suppose")
    |> mes("you'll want to review some")
    |> mes("of the easier recipes now~")
  end

  defp acknowledge_cookbook(ctx, _level), do: ctx

  defp explain_borrowing_condition(ctx) do
    ctx
    |> cutin("orleans_1", 0)
    |> mes("[Charles Orleans]")
    |> mes("Now, before I let you")
    |> mes("borrow one of my beloved")
    |> mes("cookbooks, I have a small")
    |> mes("condition that you must fulfill. ")
    |> next()
  end

  defp describe_cookbook_fee(ctx, 1) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("When I was a young child,")
    |> mes("my family was destitute to")
    |> mes("the point where we live off")
    |> mes("leftover vegetables. Even")
    |> mes("Monster's Feed was a prime")
    |> mes("delicacy back in those days.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Back then, my father would")
    |> mes("always serve us Pumpkin.")
    |> mes("I grew sick of it as a boy, but")
    |> mes("now it brings back memories")
    |> mes("of those days of innocence.")
    |> next()
    |> mes("[Charles Orleans]")
    |> mes("Why don't we do this?")
    |> mes("If you bring me 10 Pumpkins,")
    |> mes("I will let you borrow one of")
    |> mes("my Level 1 Cookbooks.")
  end

  defp describe_cookbook_fee(ctx, 2) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Today, I have a craving")
    |> mes("for a cup of tea. Of course,")
    |> mes("you cannot enjoy tea without")
    |> mes("crackers or cookies. Please")
    |> mes("bring me 5 Well-Baked Cookies")
    |> mes("to borrow my Level 2 Cookbook.")
  end

  defp describe_cookbook_fee(ctx, 3) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("You know that specialty")
    |> mes("dish from Amatsu? I've")
    |> mes("been craving that lately.")
    |> mes("Please bring me 5 Sushi,")
    |> mes("and I'll let you borrow a")
    |> mes("Level 3 Cookbook, okay?")
  end

  defp describe_cookbook_fee(ctx, 4) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Oh, I'm in the mood for")
    |> mes("some cuisine from Kunlun.")
    |> mes("Would you bring me some of")
    |> mes("that delicious Bao? 5 would")
    |> mes("be perfect. Then, I'll let you")
    |> mes("borrow my Level 4 Cookbook.")
  end

  defp describe_cookbook_fee(ctx, 5) do
    ctx
    |> cutin("orleans_7", 0)
    |> mes("[Charles Orleans]")
    |> mes("Lately, my pantry has been")
    |> mes("in some dire need of Shoots.")
    |> mes("They're a tasty ingredient with")
    |> mes("unignorable health value. Bring")
    |> mes("me 10 of those, and you can")
    |> mes("borrow a Level 5 Cookbook.")
  end

  defp confirm_cookbook_fee(ctx, cookbook_level) do
    {item_id, amount, options} = cookbook_fee(cookbook_level)

    if count_item(ctx, item_id) >= amount do
      {ctx, choice} = ctx |> next() |> select(options)

      if accept_cookbook_trade?(cookbook_level, choice) do
        ctx
        |> thank_for_cookbook_fee(cookbook_level)
        |> exchange_cookbook()
      else
        decline_cookbook_fee(ctx, cookbook_level)
      end
    else
      finish_conversation(ctx)
    end
  end

  defp cookbook_fee(1), do: {535, 10, ["Give 10 Pumpkins and Current Cookbook", "Cancel"]}
  defp cookbook_fee(2), do: {538, 5, ["Give Cookies and Current Cookbook", "Cancel"]}
  defp cookbook_fee(3), do: {551, 5, ["Give Sushi and Current Cookbook", "Cancel"]}
  defp cookbook_fee(4), do: {553, 5, ["Give Bao and Current Cookbook", "Cancel"]}
  defp cookbook_fee(5), do: {711, 10, ["Give Shoots and Current Cookbook", "Quit"]}

  defp accept_cookbook_trade?(3, choice), do: Rathena.truthy?(choice)
  defp accept_cookbook_trade?(_level, choice), do: choice == 1

  defp thank_for_cookbook_fee(ctx, 1) do
    ctx
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Perfect, you've brought")
    |> mes("me 10 Pumpkins! I can't")
    |> mes("want to taste these flavors")
    |> mes("that I used to experience")
    |> mes("everyday in my childhood.")
    |> next()
  end

  defp thank_for_cookbook_fee(ctx, 2) do
    ctx
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Oh, you brought these")
    |> mes("cookies much quicker")
    |> mes("than I had expected!")
    |> mes("Great, now I can put")
    |> mes("the tea on, relax, then")
    |> mes("enjoy a delicious snack~")
    |> next()
  end

  defp thank_for_cookbook_fee(ctx, 3) do
    ctx
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Ooh, these look so fresh!")
    |> mes("And the presentation is also")
    |> mes("wonderful! These must have")
    |> mes("been prepared by a skilled chef! ")
    |> next()
  end

  defp thank_for_cookbook_fee(ctx, 4) do
    ctx
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Great, you actually")
    |> mes("brought them! These")
    |> mes("Bao look especially")
    |> mes("scrumptious! I can't")
    |> mes("wait to have a taste!")
    |> next()
  end

  defp thank_for_cookbook_fee(ctx, 5) do
    ctx
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("Goodness, these are")
    |> mes("some high quality Shoots!")
    |> mes("These look so good, I'm")
    |> mes("sure that you you can")
    |> mes("even eat them raw!")
    |> next()
  end

  defp decline_cookbook_fee(ctx, 1) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Oh, how I miss the")
    |> mes("taste of Pumpkins!")
    |> mes("Ahhh, how nostalgic~")
    |> finish_conversation()
  end

  defp decline_cookbook_fee(ctx, 2) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Ohh...")
    |> mes("I must have some tea")
    |> mes("soon... But the experience")
    |> mes("isn't complete without any")
    |> mes("Well-Baked Cookies to munch~")
    |> finish_conversation()
  end

  defp decline_cookbook_fee(ctx, 3) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Ahhh, Sushi...")
    |> mes("It's one of the few")
    |> mes("things I don't know")
    |> mes("how to make extremely")
    |> mes("well. Can you believe that?")
    |> finish_conversation()
  end

  defp decline_cookbook_fee(ctx, 4) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Oh...")
    |> mes("It's been so long")
    |> mes("since I've had a taste")
    |> mes("of that delicious Bao.")
    |> mes("I'd cook it myself, but")
    |> mes("I don't know the secret!")
    |> finish_conversation()
  end

  defp decline_cookbook_fee(ctx, 5) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("I'm going to need to")
    |> mes("cook with those Shoots")
    |> mes("soon, so I'd appreciate it")
    |> mes("if you'd do this little favor~")
    |> finish_conversation()
  end

  defp exchange_cookbook(ctx) do
    old_book = get_local(ctx, :old_book, 0)
    new_book = get_local(ctx, :new_book, 0)
    {item_id, amount, _options} = cookbook_fee(new_book)

    ctx
    |> delitem(7471 + old_book, 1)
    |> delitem(item_id, amount)
    |> give_item(7471 + new_book, 1)
    |> hand_over_cookbook()
  end

  defp hand_over_cookbook(ctx) do
    ctx
    |> mes("[Charles Orleans]")
    |> mes("Well, as promised,")
    |> mes("here's the cookbook")
    |> mes("that you asked for. Take")
    |> mes("good care of it--don't sell")
    |> mes("it or lose it or anything like")
    |> mes("that. Good luck cooking now~")
    |> finish_conversation()
  end

  defp explain_inspiration(ctx) do
    ctx
    |> cutin("orleans_3", 0)
    |> mes("[Charles Orleans]")
    |> mes("What do you mean,")
    |> mes("''Who do I cook for?''")
    |> mes("That's a strange question")
    |> mes("with a simple answer. I'm")
    |> mes("an artiste that must bring")
    |> mes("more of my art into the world.")
    |> next()
    |> cutin("orleans_3", 0)
    |> mes("[Charles Orleans]")
    |> mes("Wait, wait...")
    |> mes("Have you been speaking")
    |> mes("to Madeleine Chu? She")
    |> mes("didn't say anything out")
    |> mes("of the ordinary did she?")
    |> mes("Because if she did, ignore her!")
    |> next()
    |> cutin("orleans_6", 0)
    |> mes("[Charles Orleans]")
    |> mes("No. There is")
    |> mes("no special reason")
    |> mes("why my spirit to create")
    |> mes("culinary masterpieces has")
    |> mes("been reinvigorated lately...")
    |> finish_conversation()
  end

  defp rest_from_teaching(ctx) do
    ctx
    |> cutin("orleans_5", 0)
    |> mes("[Charles Orleans]")
    |> mes("Please, do not worry")
    |> mes("yourself about it. Just")
    |> mes("let me rest for now~")
    |> finish_conversation()
  end

  defp finish_conversation(ctx) do
    ctx |> close() |> cutin("", 255)
  end
end
